Nodes = require './nodes'
{last} = require './helpers'
{INVERSES} = require './rewriter'

Object.create ?= (proto) ->
    (ctor = ->).prototype = proto
    new ctor

# ## Lexer
class Lexer extends require('./lexer').Lexer
    constructor: (report_error) ->
        # Override `error` to just report (instead of throwing) and return to
        # lexing.
        @error = (message) -> report_error @line, message

    # Redefine `pair` to be more forgiving for unclosed parenthesis
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
        # unmatched tags will be reported in parser

# ## Parser
class Parser extends require('./parser').Parser
    constructor: (report_error) ->
        # Override `parseError` to report
        @failed = false
        @parseError = (message, info) ->
            @failed = true
            report_error info.line, message
        # set .yy and wrap nodes that might throw exceptions on instantiation
        @yy = Object.create Nodes
        for node_name in ['Assign', 'Param', 'For']
            @yy[node_name] = class Wrapper extends Nodes[node_name]
                constructor: ->
                    try
                        super
                    catch message
                        report_error @first_line, message
                name = node_name
                toString: (idt = '') ->
                    super idt, name

    # Add a `.yylloc` to lexer
    lexer:
        lex: ->
            [tag, @yytext, @yylineno] = @tokens[@pos++] or ['']
            @yylloc =
                first_line:     @yylineno
                last_line:      @yylineno
                first_column:   0
                last_column:    0
            tag
        setInput: (@tokens) ->
            @pos = 0
        upcomingInput: ->
            ''

# ## helper functions for the AST walker

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

# Get the "real" name from a Class node.
# This is the name of the constructor function in the compiled JavaScript.
# Returns nothing on failure.
get_class_name = (node) ->
    try
        node.determineName()
    catch ex
        undefined

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
            parts.push '_'
    parts

# ## Parser and tree builder
class CoffeeScriptParser
    constructor: (config={}) ->
        # read config values
        @first_line = Number(config.line or 0)
        @displayCodeParameters = config.displayCodeParameters ? false
        @isCakefile = config.isCakefile ? false
        showErrors = config.showErrors ? true

        # replace overridable function
        if config.makeTreeNode?
            @make_tree_node = (args...) ->
                config.makeTreeNode args...
        if config.logError?
            @log_error = (message...) ->
                config.logError message.join(' ')
        report_error =  if not showErrors
                            ->
                        else if config.reportError?
                            (line, msg) -> config.reportError line ? null, msg
                        else
                            (line, msg) -> console.error (line ? ''), msg

        # instatiate lexer and parser
        @lexer = new Lexer(report_error)
        @parser = new Parser(report_error)

    #### Interface
    compile: (source) ->
        try
            ast = @parser.parse(
                    @lexer.tokenize String source, {line: @first_line})
        catch err
            @log_error "Parser error: #{err}"
            return null
        if not @parser.failed
            try
                return ast.compile(bare: true)
            catch err
                @log_error "Compiler error: #{err}"
        return null

    nodes: (source) ->
        @parser.parse(
            @lexer.tokenize String source, {line: @first_line}
        ).expressions

    parse: (source, root='<file>') ->
        if typeof root is 'string'
            root = @make_tree_node(root)
        try
            nodes = @nodes(source)
        catch err
            @log_error "Parser error: #{err}"
            return root
        try
            if nodes.length
                @walk_ast(nodes, root, nodes[nodes.length-1].last_line)
        catch err
            @log_error "Treemaking error: #{err}"
        return root

    #### overrideable functions
    log_error: (message...) ->
        console.error message...

    make_tree_node: (name, type, qualifier, first_line, last_line) ->
        child_nodes = []
        add: (node) -> child_nodes.push node
        pprint: -> @_pprint().join('')
        _pprint: (parts=[], prefix, last) ->
            if prefix?
                parts.push prefix
                if last
                    parts.push ' └─ '
                    prefix = prefix+'    '
                else
                    parts.push ' ├─ '
                    prefix = prefix+' │  '
            else
                prefix = ''
            switch qualifier
                when 'static'
                    parts.push '@'
                when 'hidden'
                    parts.push '-'
                when 'property', 'constructor'
                    parts.push ' '
            parts.push name
            switch type
                when "class"
                    parts.push ' class'
                when "task"
                    parts.push ' task'
            if first_line?
                parts.push ' [', first_line, '..', last_line, ']'
            parts.push '\n'
            last = child_nodes.length-1
            for child, i in child_nodes
                child._pprint(parts, prefix, i is last)
            return parts

    #### AST walker
    walk_ast: (nodes, parent, parent_last_line, parent_class, in_prototype) ->
        last_index = nodes.length-1
        for node, node_index in nodes
            # `node.last_line` can overlap the next expression if the rewriter
            # adds implicit parentheses, so we fix it here
            last_line = Math.min(node.last_line, parent_last_line)
            if node_index < last_index
                next_node_line = nodes[node_index+1].first_line
                if last_line == next_node_line
                    last_line = Math.max(node.first_line, next_node_line-1)

            node_name = null

            # **task** definitions in Cakefiles
            if @isCakefile and
                    node instanceof Nodes.Call and
                    name_from_value(node.variable)?[0] is 'task' and
                    (arg = node.args[0]) instanceof Nodes.Value and
                    name = name_from_value(arg)?[0].match(/^(['"])(.*)\1$/)?[2]
                parent.add @make_tree_node  name,
                                            'task',
                                            '',
                                            node.first_line,
                                            last_line
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
                            last_line,
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
                            last_line,
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
                            last_line,
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
                    if @displayCodeParameters
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
                                            node.first_line,
                                            last_line

                @walk_ast   node.body.expressions,
                            tree_node,
                            last_line,
                            node_is_class and (get_class_name(node) or true),
                            false
                parent.add tree_node
        return


# ## Interface

exports.CoffeeScriptParser = CoffeeScriptParser

exports.nodes = (source, config) ->
    return (new CoffeeScriptParser(config)).nodes(source)

exports.compile = (source, config) ->
    return (new CoffeeScriptParser(config)).compile(source)

exports.parse = (source, root, config) ->
    return (new CoffeeScriptParser(config)).parse(source, root)
