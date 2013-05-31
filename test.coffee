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
        config.logError     ?= (msg) -> fail 'Internal Error', msg
        config.reportError  ?= (msg, location...) ->
            location = location.filter (i) -> i?
            reported_errors.push {location, msg}

    evaluate = (expected_errors) ->
        # Find undetected error and drop reported errors that were expected.
        undetected_errors = expected_errors.filter ([location..., regex]) ->
            undetected = true
            reported_errors = reported_errors.filter (error) ->
                if "#{location}" == "#{error.location}" and regex.test error.msg
                    undetected = false
                else
                    true
            return undetected

        if undetected_errors.length
            fail 'undetected errors'
            for [location..., {source: regex}] in undetected_errors
                fail "  #{location}: /#{regex}/"
        if reported_errors.length
            fail 'unexpected errors'
            for {location, msg} in reported_errors
                fail "  #{location}: #{msg}"

        # Update global error status.
        if test_errors.length
            test.failed = true

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

test.parsing 'assignments',
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

test.parsing 'class structure',
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

test.parsing 'code in blocks',
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

test.parsing 'tasks in Cakefile',
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

test.parsing 'docco headings',
    config:
        showDoccoHeadings: true
    code: """
            # 1. Heading
            # ==========
            # 1.1. Heading lvl 2
            # ------------------
            f = ->
                # ### 1.1.1 Heading lvl 3
                f1 = ->
                # ### 1.1.2 Heading lvl 3
                f2 = ->
            # ## 1.2. Heading lvl 2
            g = ->

            # # 2. Heading lvl 1
            class C # ## not recognized as heading
            class D # Also not a heading
            # --------------------------
            class E
          """
    tree: """
            <root>
             ├─ 1. Heading [0..1]
             │   ├─ 1.1. Heading lvl 2 [2..3]
             │   │   └─ f [4..8]
             │   │       ├─ 1.1.1 Heading lvl 3 [5..5]
             │   │       │   └─ f1 [6..6]
             │   │       └─ 1.1.2 Heading lvl 3 [7..7]
             │   │           └─ f2 [8..8]
             │   └─ 1.2. Heading lvl 2 [9..9]
             │       └─ g [10..10]
             └─ 2. Heading lvl 1 [12..12]
                 ├─ C class [13..13]
                 ├─ D class [14..14]
                 └─ E class [16..16]
          """

test.parsing 'reserved identifiers',
    code: """
            yield = -> private"""
    tree: """
            <root>
             └─ yield [0..0]"""
    [ 0, 0,  /yield/   ]
    [ 0, 11, /private/ ]

test.parsing 'unclosed parentheses in block',
    code: """
            f = ->
                x([{
            g = ->"""
    tree: """
            <root>
             ├─ f [0..1]
             └─ g [2..2]"""
    [ 1, 8, /\(/ ]
    [ 1, 8, /\[/ ]
    [ 1, 8, /{/  ]

test.parsing 'indentation errors',
    code: """
            f = ->
              ->
                1 /
            0
            g = ->
            0
              0
            h = ->"""
    tree: """
            <root>
             ├─ f [0..2]
             ├─ g [4..4]
             └─ h [7..7]"""
    [ 3, 0,     /missing indentation/i    ]
    [ 6, 0, 1,  /unexpected indentation/i ]

test.parsing 'unexpected end',
    code: """
        a/"""
    [0, 2, /unexpected end/i]

test.parsing 'unexpected end while in block',
    code: """
        f = -> a/"""
    [0, 8, /unexpected end/i]

test.parsing 'code parameters',
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

test.parsing 'illegal code parameters',
    config:
        displayCodeParameters: true
    code: """
        f = (eval, arguments=-1) ->"""
    tree: """
            <root>
             └─ f(eval, arguments) [0..0]"""
    [ 0,  5,  8, /eval/     ]
    [ 0, 11, 19, /arguments/]
    # NOTE
    # Illegal parameter names in destructuring assignments are processed at
    # compile time and will not produce errors while parsing. Hence no test
    #       g = ([eval], {arguments}) ->

test.parsing 'with line offset',
    config:
        line: line_off = Math.ceil(Math.random()*42)
    code: """
        f = (eval, arguments=-1) ->
            yield = -> private"""
    tree: """
            <root>
             └─ f [#{line_off}..#{line_off+1}]
                 └─ yield [#{line_off+1}..#{line_off+1}]"""
    [ line_off,    5,  8, /eval/      ]
    [ line_off,   11, 19, /arguments/ ]
    [ line_off+1,  4,     /yield/     ]
    [ line_off+1, 15,     /private/   ]

test.parsing 'special class names',
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
    [8, 10, 13, /eval/]

test.compiling 'harmless code',
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

test.compiling 'with lexer errors',
    code: """
            class yield
            private = ([eval], {arguments}) ->"""
    compiled: null
    [ 0, 6, /yield/   ]
    [ 1, 0, /private/ ]
    # NOTE
    # The compiler should not be executed if errors have been encountered by
    # lexer or parser. The compiler errors on the last code line should
    # therefore not be reported.

test.compiling 'with parser errors',
    code: """
            f = (eval, arguments) ->
            g = ([eval], {arguments}) ->"""
    compiled: null
    [ 0,  5,  8, /eval/     ]
    [ 0, 11, 19, /arguments/]
    # NOTE
    # The compiler should not be executed if errors have been encountered by
    # lexer or parser. The compiler errors on the last code line should
    # therefore not be reported.

test.compiling 'with compiler errors',
    code: """
            f = ([eval], {arguments}) ->"""
    compiled: null
    [ 0,  6,  9, /eval/     ]
    [ 0, 14, 22, /arguments/]

test.compiling 'with lexer and parser errors and line offset',
    config:
            line: line_off = Math.ceil(Math.random()*42)
    code: """
            private = -> yield
            f = (eval, arguments) ->
            g = ([eval], {arguments}) ->"""
    compiled: null
    [ line_off,    0,     /private/   ]
    [ line_off,   13,     /yield/     ]
    [ line_off+1,  5, 8,  /eval/      ]
    [ line_off+1, 11, 19, /arguments/ ]
    # NOTE
    # The compiler should not be executed if errors have been encountered by
    # lexer or parser. The compiler errors on the last code line should
    # therefore not be reported.

test.compiling 'with compiler error and line offset',
    config:
            line: line_off = Math.ceil(Math.random()*42)
    code: """
            g = ([eval], {arguments}) ->"""
    compiled: null
    [ line_off,  6,  9, /eval/      ]
    [ line_off, 14, 22, /arguments/ ]

process.on 'exit', ->
    if test.failed then process.exit 1