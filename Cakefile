fs      = require 'fs'
{spawn} = require 'child_process'

# Extend `task` to use `option_defaults` and provide callbacks (task chaining)
(->
    tasks = {}
    _task = global.task
    global.task = (name, description, actions...) ->
        [fnc, callchain...] = for action in actions
            if typeof action is 'function'
                (options, next_task, more_tasks...) ->
                    console.log "running task #{name}..."
                    options[key] ?= val for key, val of option_defaults
                    callback = -> next_task?(options, more_tasks...)
                    action(options, callback)
                    callback?() if action.length < 2
            else
                tasks[action] ? (throw "No such task: #{action}")
        tasks[name] = (options, callbacks...) ->
            fnc(options, callchain.concat(callbacks)...)
        _task name, description, tasks[name]
)()

# Options and defaults
option  '-n', '--node [CMD]',           'path to node executable'
option  '-c', '--coffeescript [DIR]',   'path to coffeescript (incl. source)'
option  '-s', '--source [DIR]',         'source dir'
option  '-b', '--build [DIR]',          'build dir'
option  '-o', '--dist [PATH]',          'path of merged javascript file'
option_defaults =
    node:           'node'
    coffeescript:   './coffee-script'
    source:         './src'
    build:          './build/coffee-script'
    dist:           './CoffeeScriptParser.js'

# Helper to execute a command with a callback
run = (command, args, callback) ->
    proc =         spawn command, args
    proc.stdout.pipe process.stdout, end: false
    proc.on        'exit', (status) ->
        process.exit(1) if status != 0
        callback() if typeof callback is 'function'

# CoffeeScript source files that will be compiled and merged into dist file
LIBS = ['helpers', 'rewriter', 'lexer', 'scope', 'nodes']

## Tasks
task 'build:source', 'build from source', (o, callback) ->
    files = LIBS.map (name) -> "#{o.coffeescript}/src/#{name}.coffee"
    files.push  "#{o.source}/grammar.coffee",
                "#{o.source}/CoffeeScriptParser.coffee"
    run o.node,
        ["#{o.coffeescript}/bin/coffee", '-c', '-o', o.build].concat(files),
        callback

task 'build:parser', 'build the parser', 'build:source', (o)->
    parser = require("#{o.build}/grammar").parser
    parser.hasErrorRecovery = true # workaround preserving error recovery code
    code = """
    var Parser = function Parser(){};
    Parser.prototype = #{parser.generateModule_()};
    exports.Parser = Parser;
    """
    fs.writeFileSync "#{o.build}/parser.js", code

task 'merge', 'merge compiled source to CoffeeScriptParser.js', (o)->
    code = for name in LIBS.concat('parser')
        """
        require['./#{name}'] = new function() {
            var exports = this;
            #{fs.readFileSync "#{o.build}/#{name}.js"}
            return this;
        };
        """
    code = """
        if (typeof exports === 'undefined') { var exports = this; }
        function require(path){ return require[path]; }
        #{code.join('\n')}
        #{fs.readFileSync "#{o.build}/CoffeeScriptParser.js"}
    """
    fs.writeFileSync o.dist, code

task 'test', 'run tests', (o, callback) ->
    run o.node,
        ["#{o.coffeescript}/bin/coffee", './test.coffee', o.dist],
        callback

task 'build', 'build everything and run tests',
        'build:parser', 'merge', 'test'
