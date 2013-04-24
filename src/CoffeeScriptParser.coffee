# ## Global objects and helpers

# AST nodes
Nodes = require './nodes'

# Unified output to stderr for node.js and Rhino.
print_error =   if java?
                    (args...) -> java.lang.System.err.println args.join(' ')
                else
                    (args...) -> console.error args...

# Error for terminating compilation after error reporting happened.
ABORT_COMPILATION = new Error('Abort compilation')


# ## Lexer
class Lexer extends require('./lexer').Lexer
    {last} = require './helpers'
    {INVERSES} = require './rewriter'

    constructor: (report_error) ->
        # Override to just report (instead of throwing) and return to lexing.
        @error = (message) ->
            @failed = true
            report_error @chunkLine, message

    # Reset failed flag before lexing.
    tokenize: ->
        @failed = false
        return super

    # Redefine `pair` to be more forgiving for unclosed parenthesis.
    pair: (tag) ->
        if tag is wanted = last @ends
            @ends.pop()
        else if wanted is 'OUTDENT'
            # Auto-close INDENT
            @indent -= size = last @indents
            @outdentToken size, true
            @pair tag
        else if tag is 'OUTDENT' and wanted in [')','}',']']
            # auto-close and report unmatched parenthesis in indented blocks
            @error "unclosed #{INVERSES[wanted]}"
            @token wanted, wanted
            @ends.pop()
            @pair tag
        # Unmatched tags will be reported in Parser.

# ## Parser
class Parser extends require('./parser').Parser
    constructor: (@report_error) ->
        @yy = Nodes

        # Errors from node construction and compilation
        parser = this
        @yy.Base::error = (message) -> parser.error @locationData, message

    # Reset `failed` flag before parsing.
    parse: ->
        @failed = false
        return super

    # Add a `.yylloc` to lexer.
    lexer:
        lex: ->
            token = @tokens[@pos++]
            if token
                [tag, @yytext, @yylloc] = token
                @yylineno = @yylloc.first_line
            else
                tag = ''
            tag
        setInput: (@tokens) ->
            @pos = 0
        upcomingInput: ->
            ''
        # helper function for parseError
        nextRealToken: ->
            i = @pos
            while t = @tokens[i++]
                break unless t.generated and t[0] in ['OUTDENT', 'TERMINATOR']
            t

    # Override Jison parser error function
    parseError: (message, {line, token:tag}) ->
        switch tag
            when 'INDENT'
                message = "unexpected indentation"
            when 'OUTDENT'
                # Move error to the start of the next token.
                # (Skip whitespace and generated tokens)
                if token = @lexer.nextRealToken()
                    message = "missing indentation"
                    {first_line, first_column} = token[2]
                    location =
                        first_line:     first_line
                        first_column:   first_column
                        last_line:      first_line
                        last_column:    first_column
                else
                    tag = 1     # It's actually an unexpected EOF error.

        if tag is 1
            message = "unexpected end of input"
            location = null
        else
            message ?= "unexpected #{tag}"
            location ?= @lexer.yylloc

        @error location, message

    error: (location, message) ->
        @failed = true
        @report_error location?.first_line, message

# ## Parser and tree builder
class CoffeeScriptParser
    constructor: (@config={}) ->
        # set default config values
        @config.displayCodeParameters ?= false
        @config.isCakefile ?= false
        @config.line ?= 0

        # instantiate lexer and parser
        @lexer = new Lexer(@report_error)
        @parser = new Parser(@report_error)

    #### Interface
    nodes: (source) ->
        source = String source  # make sure it's a javascript string
        try
            return @parser.parse @lexer.tokenize source, line: @config.line
        catch error
            throw error
            @log_error "Parser error: #{error}"
        null

    compile: (source) ->
        ast = @nodes(source)
        if ast and not (@lexer.failed or @parser.failed)
            try
                result = ast.compile(bare: true)
            catch error
                @parser.failed = true
                @log_error "Compiler error: #{error}"
            if @parser.failed
                # Compile errors set `failed` to true (via Base::error).
                result = null
        result

    parse: (source, root='<file>') ->
        if typeof root is 'string'
            root = @make_tree_node(root)

        nodes = @nodes(source)?.expressions
        if nodes?.length
            try
                @walk_ast(nodes, root)
            catch error
                @log_error "Tree builder error: #{error}"
        return root

    #### Overrideable functions
    #   These may be redefined by their CamelCase counterparts in the `config`
    #   object specified on instantiation.

    # Report an error from parser or compiler to the user.
    report_error: (line, error) =>
        error = error.message if error instanceof Error
        if @config.reportError?
            @config.reportError line ? null, error
        else
            print_error "#{line ? '?'}: #{error}"

    # Error logger
    log_error: (message...) ->
        if @config.logError?
            @config.logError message.join(' ')
        else
            print_error message...

    # Build a node of the structure tree.
    # It must have a constructor with the same signature as this function and
    # a method `add` for adding child nodes.
    make_tree_node: (name, type, qualifier, first_line, last_line) ->
        if @config.makeTreeNode?
            @config.makeTreeNode(name, type, qualifier, first_line, last_line)
        else
            new TreeNode(name, type, qualifier, first_line, last_line)

    # A simple structure tree / node for console output and testing.
    class TreeNode
        PREFIX = static: '@', hidden: '-', property: ' ', constructor: ' '
        POSTFIX = class: ' class', task: ' task'
        constructor: (name, type, qualifier, first_line, last_line) ->
            @children = []
            @name_display = [ PREFIX[qualifier], name, POSTFIX[type] ]
            if first_line?
                @name_display.push ' [', first_line, '..', last_line, ']'
        add: (node) ->
            @children.push node
        format: (parts=[], prefix='', is_last) ->
            if is_not_root = parts.length
                parts.push prefix
                if is_last
                    parts.push  ' └─ '
                    prefix +=   '    '
                else
                    parts.push  ' ├─ '
                    prefix +=   ' │  '
            parts.push @name_display...
            last_index = @children.length-1
            for child, i in @children
                parts.push '\n'
                child.format(parts, prefix, i is last_index)
            return parts.join('') unless is_not_root

    #### AST walker
    walk_ast: (nodes, parent, parent_class, in_prototype) ->
        for node, node_index in nodes
            node_name = null

            # **task** definitions in Cakefiles
            if @config.isCakefile and
                    node instanceof Nodes.Call and
                    name_from_value(node.variable)?[0] is 'task' and
                    (arg = node.args[0]) instanceof Nodes.Value and
                    name = name_from_value(arg)?[0].match(/^(['"])(.*)\1$/)?[2]
                parent.add @make_tree_node  name,
                                            'task',
                                            '',
                                            node.locationData.first_line,
                                            node.locationData.last_line
                continue
            # **assign expression**
            else if node instanceof Nodes.Assign
                # may be chained, so we collect all `variable`s first.
                assignees = [node.variable]
                node = node.value
                while node instanceof Nodes.Assign
                    assignees.push node.variable
                    node = node.value
                if node_is_class = node instanceof Nodes.Class
                    if not in_prototype
                        assignees.unshift node.variable
                    node_name = get_name(assignees)
                else if node instanceof Nodes.Code
                    node_name = get_name(assignees)
            # **class expression**
            else if node_is_class = node instanceof Nodes.Class
                node_name = get_name([node.variable])
            # **property assignments in class declarations**
            # are represented in the AST by a Value node containing an Obj node.
            # We just walk over its children (which are Assign nodes) with
            # `in_prototype=true`.
            else if parent_class and node.isObject?(true)
                @walk_ast   node.base.properties,
                            parent,
                            parent_class,
                            true
                continue
            # **switch expression**
            # Collect expressions from when blocks walk over them with the
            # current context.
            else if node instanceof Nodes.Switch
                expressions = []
                for case_ in node.cases
                    expressions.push case_[1].expressions...
                if node.otherwise?
                    expressions.push node.otherwise.expressions...
                @walk_ast   expressions,
                            parent,
                            parent_class,
                            in_prototype
                continue
            # **Other expressions with a body** (e.g. `while`, `if`, `for`)
            # Simply walk over child expressions with the current context.
            else if node.body?
                # if expressions may have multiple bodies.
                # Collect expressions from `if`, `else if` and `else` blocks.
                if node instanceof Nodes.If
                    expressions = node.body.expressions[..]
                    while node.isChain
                        node = node.elseBody.unwrap()
                        expressions.push node.body.expressions...
                    if node.elseBody?
                        expressions.push node.elseBody.expressions...
                else
                    expressions = node.body.expressions
                @walk_ast   expressions,
                            parent,
                            parent_class,
                            in_prototype
                continue

            # If we have recognized a node with a viable name, make a tree
            # node and add it to the parent.
            if node_name
                # Beautify name and determine the type of node.
                name = null
                qualifier = ''
                if node_name.length>1 and node_name[0] in ['this', parent_class]
                    if parent_class
                        if node_name.length > 2 and node_name[1] is 'prototype'
                            name = node_name.slice(2).join('.')
                            qualifier = 'property'
                        else
                            name = node_name.slice(1).join('.')
                            qualifier = 'static'
                    else
                        name = '@'+node_name.slice(1).join('.')
                else
                    if in_prototype
                        if node_name[0] is 'constructor'
                            qualifier = 'constructor'
                        else
                            qualifier = 'property'
                    else if parent_class
                        qualifier = 'hidden'
                    name = node_name.join('.')
                name = name.replace('.prototype.', '::')

                if node_is_class
                    type = 'class'
                else
                    type = 'code'
                    if @config.displayCodeParameters
                        params = []
                        for param in node.params
                            params.push ', ' if params.length
                            params.push format_param(param.name)...
                            params.push '...' if param.splat
                        name = "#{name}(#{params.join('')})"

                # Make tree node and walk over children
                tree_node = @make_tree_node name,
                                            type,
                                            qualifier,
                                            node.locationData.first_line,
                                            node.locationData.last_line

                @walk_ast   node.body.expressions,
                            tree_node,
                            node_is_class and (@get_class_name(node) or true),
                            false
                parent.add tree_node
        return

    # ## Helper functions for the AST walker

    # Get the "real" name from a Class node.
    # This is the name of the constructor function in the compiled
    # JavaScript.
    get_class_name: (node) ->
        try
            name = node.determineName() or '_Class'
            name = "_#{name}" if name.reserved
            return name
        catch error
            @report_error node.locationData.first_line, error
            return node.variable.base.value

    # Get name (an array of strings) from a Value node.
    # If this fails, return nothing.
    name_from_value = (value) ->
        if not value.base instanceof Nodes.Literal
            return
        name = [value.base.value]
        for prop in value.properties
            part = null
            if prop instanceof Nodes.Access
                part = prop.name.value
            else if prop instanceof Nodes.Index and
                    prop.index instanceof Nodes.Value and
                    match = prop.index.base.value.match /^(["'])([A-Za-z]\w*)\1$/
                part = match[2]
            if part
                name.push part
            else
                return
        return name

    # Get a name (as an array of strings) from a list of Value nodes.
    # If this fails return nothing.
    get_name = (assignables) ->
        for assignable in assignables when assignable
            if name = name_from_value(assignable)
                return name

    # Format a code parameter.
    format_param = (node, parts=[], in_obj=false) ->
        if node instanceof Nodes.Literal
            parts.push node.value
        else if node instanceof Nodes.Value and node.base instanceof Nodes.Literal
            if name = name_from_value(node)
                if name[0] is 'this'
                    parts.push '@'
                    name = name.slice(1)
                parts.push name.join('.')
        else if in_obj and node instanceof Nodes.Assign
            parts.push node.variable.base.value
        else if not in_obj and node instanceof Nodes.Splat
            format_param(node.name, parts, false)
            parts.push '...'
        else
            if node instanceof Nodes.Value and (node.isArray() or node.isObject())
                node = node.base
            if not in_obj and node instanceof Nodes.Arr
                parts.push '['
                for obj, i in node.objects
                    parts.push(', ') if i
                    format_param(obj, parts, false)
                parts.push ']'
            else if not in_obj and node instanceof Nodes.Obj
                parts.push '{'
                for obj, i in node.objects
                    parts.push(', ') if i
                    format_param(obj, parts, true)
                parts.push '}'
            else
                parts.push '<?>'
        parts


# ## Interface

exports.CoffeeScriptParser = CoffeeScriptParser

exports.nodes = (source, config) ->
    return (new CoffeeScriptParser(config)).nodes(source)

exports.compile = (source, config) ->
    return (new CoffeeScriptParser(config)).compile(source)

exports.parse = (source, root, config) ->
    return (new CoffeeScriptParser(config)).parse(source, root)
