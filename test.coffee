{puts, print} = require 'util'
{parse} = require process.argv[2] ? './CoffeeScriptParser'

any_test_failed = false
reported_errors = []

config_defaults =
    logError: -> #ignore
    reportError: (line, message) -> reported_errors.push [line, message]

test = (name, test, expected_errors...) ->
    reported_errors = []
    test_errors = []

    test.config ?= {}
    test.config[key] ?= config_defaults[key] for key of config_defaults

    print "testing #{name}... "
    tree = parse(test.code, '<root>', test.config)
    if test.tree? and (tree=tree.pprint().trim()) != test.tree.trim()
        test_errors.push 'unexpected tree structure', tree
    undetected_errors = expected_errors.filter ([line, regex]) ->
        found = false
        i = 0
        while i<reported_errors.length
            [reported_line, message] = reported_errors[i]
            if line == reported_line and message.match(regex)
                reported_errors.splice(i, 1)
                found = true
            else
                i++
        return not found
    if undetected_errors.length
        test_errors.push 'undetected errors'
        for err in undetected_errors
            test_errors.push "  #{err[0]}: /#{err[1].source}/"
    if reported_errors.length
        test_errors.push 'unexpected errors'
        for err in reported_errors
            test_errors.push "  #{err[0]}: #{err[1]}"
    if test_errors.length
        any_test_failed = true
        puts 'FAIL'
        puts '----------------'
        puts test_errors...
        puts '----------------'
    else
        puts 'OK'

test 'assignments'
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

test 'class structure'
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

test 'code in blocks'
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

test 'tasks in Cakefile'
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

test 'reserved identifiers'
    code: """
            yield = -> private"""
    tree: """
            <root>
             └─ yield [0..0]"""
    [0, /yield/]
    [0, /private/]

test 'unclosed parentheses in block'
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

test 'code parameters'
    config:
        displayCodeParameters: true
    code: """
        f = (a, b, c) ->
        g = (a='default', b=a) ->
        h = ([a, b], {c:d, e}) ->
        i = ([[a, [b]]], {c:[d], e:{f}}) ->"""
    tree: """
            <root>
             ├─ f(a, b, c) [0..0]
             ├─ g(a, b) [1..1]
             ├─ h([a, b], {c, e}) [2..2]
             └─ i([[a, [b]]], {c, e}) [3..3]"""

test 'illegal code parameters'
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
    # compile time and will not produce errors while parsing. Hence no test as
    #       g = ([eval], {arguments}) ->

if any_test_failed
    process.stdout.on 'drain', -> process.exit(1)