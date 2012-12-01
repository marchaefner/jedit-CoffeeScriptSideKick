# ## Test infrastructure

class test  # Misuse class for scoping, it is actually used as an object
    {puts, print} = require 'util'
    {parse, compile} = require process.argv[2] ? './CoffeeScriptParser'

    @failed = false                         # Indicate failure of any test.
    reported_errors = test_errors = null    # Declare at this scope level.

    fail = -> test_errors.push arguments... # Shortcut

    setup = (test) ->
        test_errors = []
        reported_errors = []
        config = test.config ?= {}
        config.reportError  ?= (line, msg) -> reported_errors.push {line, msg}
        config.logError     ?= (msg) -> fail 'Internal Error', msg

    evaluate = (expected_errors) ->
        # Find undetected error and drop reported errors that were expected.
        undetected_errors = expected_errors.filter ([line, regex]) ->
            undetected = true
            reported_errors = reported_errors.filter (error) ->
                if line == error.line and regex.test error.msg
                    undetected = false
                else
                    true
            return undetected
        if undetected_errors.length
            fail 'undetected errors'
            for [line, {source: regex}] in undetected_errors
                fail "  #{line}: /#{regex}/"
        if reported_errors.length
            fail 'unexpected errors'
            for {line, msg} in reported_errors
                fail "  #{line}: #{msg}"

        test.failed and= test_errors.length # Set global status.

    print_report = ->
        if test_errors.length
            puts 'FAIL'
            puts '----------------'
            puts test_errors...
            puts '----------------'
        else
            puts 'OK'

    method = (test_name, test_method) ->    # Used to define test methods
        (description, test, expected_errors...) ->
            print "test #{test_name} #{description}... "
            setup(test)
            test_method(test)
            evaluate(expected_errors)
            print_report()

    #### Test methods

    @parsing = method 'parsing', (test) ->
        tree = parse(test.code, '<root>', test.config)
        if test.tree? and (tree=tree.format()) != test.tree.trim()
            fail 'unexpected tree structure', tree

    minify = (js) ->
        js?.replace ///     # Remove all
                \n          #  newlines
                | \s+(?=\W) #  spaces before spaces, operators, brackets, etc.
                | (\W)\s+   #  spaces after operators, brackets, etc.
            ///g,
            '$1'    # Keep matched chars from the last alternative.

    @compiling = method 'compiling', (test) ->
        compiled = compile(test.code, test.config)
        # Use minify to get a canonical form.
        if compiled? and minify(compiled) != minify(test.compiled)
            fail 'unexpected compiler output', compiled

# ## Parser tests

test.parsing 'assignments'
    code: """
            f = ->
                g = ->
                    class C
                D = class
                    h = ->
          """
    tree: """
            <root>
             └─ f [0..4]
                 ├─ g [1..2]
                 │   └─ C class [2..2]
                 └─ D class [3..4]
                     └─ -h [4..4]
         """

test.parsing 'class structure'
    code: """
            class x.C
                hidden_code = ->
                class hidden_class
                prototype_method: ->
                @::prototype_method2 = ->
                C::prototype_method3 = ->
                @class_method: ->
                @class_method2 = ->
                C.class_method3 = ->
          """
    tree: """
            <root>
             └─ x.C class [0..8]
                 ├─ -hidden_code [1..1]
                 ├─ -hidden_class class [2..2]
                 ├─  prototype_method [3..3]
                 ├─  prototype_method2 [4..4]
                 ├─  prototype_method3 [5..5]
                 ├─ @class_method [6..6]
                 ├─ @class_method2 [7..7]
                 └─ @class_method3 [8..8]
          """

test.parsing 'code in blocks'
    code: """
            while false
                if false
                    f = ->
                else if true
                    C = class
                else
                    switch
                        when true
                            class D
                        else
                            g = ->
          """
    tree: """
            <root>
             ├─ f [2..2]
             ├─ C class [4..4]
             ├─ D class [8..8]
             └─ g [10..10]
          """

test.parsing 'tasks in Cakefile'
    config:
        isCakefile: true
    code: """
            f = ->
            task 'build', 'describe', ->
            task 'clear', 'clear', ->
          """
    tree: """
            <root>
             ├─ f [0..0]
             ├─ build task [1..1]
             └─ clear task [2..2]
          """

test.parsing 'reserved identifiers'
    code: """
            yield = -> private"""
    tree: """
            <root>
             └─ yield [0..0]"""
    [0, /yield/]
    [0, /private/]

test.parsing 'unclosed parentheses in block'
    code: """
            f = ->
                x([{
            g = ->"""
    tree: """
            <root>
             ├─ f [0..1]
             └─ g [2..2]"""
    [2, /\(/]
    [2, /\[/]
    [2, /{/]

test.parsing 'code parameters'
    config:
        displayCodeParameters: true
    code: """
        f = (a, b, c) ->
        g = (a='default', b=a) ->
        h = ([a, b], {c:d, e}) ->
        i = ([[a, [b]]], {c:[d], e}) ->"""
    tree: """
            <root>
             ├─ f(a, b, c) [0..0]
             ├─ g(a, b) [1..1]
             ├─ h([a, b], {c, e}) [2..2]
             └─ i([[a, [b]]], {c, e}) [3..3]"""

test.parsing 'illegal code parameters'
    config:
        displayCodeParameters: true
    code: """
        f = (eval, arguments=-1) ->"""
    tree: """
            <root>
             └─ f(eval, arguments) [0..0]"""
    [0, /eval/]
    [0, /arguments/]
    # NOTE
    # Illegal parameter names in destructuring assignments are processed at
    # compile time and will not produce errors while parsing. Hence no test
    #       g = ([eval], {arguments}) ->

test.parsing 'with line offset'
    config:
        line: line_off = Math.ceil(Math.random()*42)
    code: """
        f = (eval, arguments=-1) ->
            yield = -> private"""
    tree: """
            <root>
             └─ f [#{line_off}..#{line_off+1}]
                 └─ yield [#{line_off+1}..#{line_off+1}]"""
    [line_off, /eval/]
    [line_off, /arguments/]
    [line_off+1, /yield/]
    [line_off+1, /private/]

test.parsing 'special class names'
    code: """
            C = class
                C.hidden = ->
                _Class.static = ->
                _Class::method = ->
            D = class weird[stuff]
                weird.stuff.hidden = ->
                _Class.static = ->
                _Class::method = ->
            E = class eval
                E.hidden = ->
                eval.static = ->
                eval::method = ->
            class F.eval
                eval.hidden = ->
                _eval.static = ->
                _eval::method = ->
          """
    tree: """
            <root>
             ├─ C class [0..3]
             │   ├─ -C.hidden [1..1]
             │   ├─ @static [2..2]
             │   └─  method [3..3]
             ├─ D class [4..7]
             │   ├─ -weird.stuff.hidden [5..5]
             │   ├─ @static [6..6]
             │   └─  method [7..7]
             ├─ eval class [8..11]
             │   ├─ -E.hidden [9..9]
             │   ├─ @static [10..10]
             │   └─  method [11..11]
             └─ F.eval class [12..15]
                 ├─ -eval.hidden [13..13]
                 ├─ @static [14..14]
                 └─  method [15..15]"""
    [8, /eval/]

test.compiling 'harmless code'
    code: """
            C = class D
                constructor: ->
                @static = ->"""
    compiled: """
            var C, D;
            C = D = (function() {
              function D() {}
              D["static"] = function() {};
              return D;
            })();
         """

# ## Compiler tests

test.compiling 'with lexer errors'
    code: """
            class yield
            private = ([eval], {arguments}) ->"""
    compiled: null
    [0, /yield/]
    [1, /private/]
    # NOTE
    # The compiler should not be executed if errors have been encountered by
    # lexer or parser. The compiler errors on the last code line should
    # therefore not be reported.

test.compiling 'with parser errors'
    code: """
            f = (eval, arguments) ->
            g = ([eval], {arguments}) ->"""
    compiled: null
    [0, /eval/]
    [0, /arguments/]
    # NOTE
    # The compiler should not be executed if errors have been encountered by
    # lexer or parser. The compiler errors on the last code line should
    # therefore not be reported.

test.compiling 'with compiler errors'
    code: """
            f = ([eval], {arguments}) ->"""
    compiled: null
    [0, /eval/]
    # NOTE
    # Compilation stops after the first error. Therefore the errornous
    # `{arguments}` parameter will not be reported.

test.compiling 'with lexer and parser errors and line offset'
    config:
            line: line_off = Math.ceil(Math.random()*42)
    code: """
            private = -> yield
            f = (eval, arguments) ->
            g = ([eval], {arguments}) ->"""
    compiled: null
    [line_off, /private/]
    [line_off, /yield/]
    [line_off+1, /eval/]
    [line_off+1, /arguments/]
    # NOTE
    # The compiler should not be executed if errors have been encountered by
    # lexer or parser. The compiler errors on the last code line should
    # therefore not be reported.

test.compiling 'with compiler error and line offset'
    config:
            line: line_off = Math.ceil(Math.random()*42)
    code: """
            g = ([eval], {arguments}) ->"""
    compiled: null
    [line_off, /eval/]

if test.failed
    process.stdout.on 'drain', -> process.exit(1)