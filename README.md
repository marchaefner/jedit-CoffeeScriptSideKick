# CoffeeScript SideKick Plugin for jEdit

This [jEdit][] plugin provides a SideKick parser for the [CoffeeScript][]
language.

The SideKick tree represents (most) classes and functions according to their
position in the source code. In Cakefiles, tasks will also be added to the
tree. Errors encountered while parsing will be forwarded to ErrorList.

This plugin uses a modified version of CoffeeScript 1.4.0 which runs inside
the Rhino JavaScript engine.

## Installation

The latest released version can be installed with the jEdit Plugin Manager.

## Building

The actual parser and tree builder is written in CoffeeScript. Callbacks to
jEdit and plugin specific functionality are implemented in Java.

A full build, therefore, consists of two steps: Compilation of the
CoffeeScript source to JavaScript with `cake` (which runs the `Cakefile`)
followed by the usual jEdit plugin build process, defined in `build.xml`.
To ease the build process, a prebuild `CoffeeScriptParser.js` is already
included.

### Requirements

  * jEdit plugin building environment
  * jEdit plugins: ErrorList, SideKick and Rhino
  * [Node.js][] - required to execute the `Cakefile`
  * [Jison][] - JavaScript Parser Generator (installable with npm)

### git-submodule `coffee-script`

CoffeeScript 1.4.0 is included as a git submodule. Either clone this project
recursivly:

    git clone --recursive git://github.com/marchaefner/jedit-CoffeeScriptSideKick.git

or update the submodule after cloning:

    git submodule update --init

[jEdit]: http://jedit.org/
[CoffeeScript]: http://coffeescript.org/
[Jison]: https://zaach.github.com/jison/
[Node.js]: http://nodejs.org/