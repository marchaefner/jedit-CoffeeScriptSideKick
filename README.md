# CoffeeScript SideKick Plugin for jEdit

This [jEdit][] plugin provides a SideKick parser for the [CoffeeScript][]
language.

The SideKick tree represents (most) classes and functions according to their
position in the source code. In Cakefiles, tasks will also be added to the
tree. Errors encountered while parsing will be forwarded to ErrorList.

This plugin uses a modified version of CoffeeScript 1.4.0 which runs inside
the Rhino JavaScript engine.

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
  * jEdit plugins: ErrorList, SideKick and Rhino (version 1.7R4, see below)
  * [Node.js][] - required to execute the `Cakefile`
  * [Jison][] - JavaScript Parser Generator (installable with npm)

### git-submodule `coffee-script`

CoffeeScript 1.4.0 is included as a git submodule. Either clone this project
recursivly:

    git clone --recursive git://github.com/marchaefner/jedit-CoffeeScriptSideKick.git

or update the submodule after cloning:

    git submodule update --init

### Updating the Rhino Plugin

This plugin builds (and therefore runs) only with Rhino version 1.7R4.
At the current time (2012/11) the official Rhino plugin ships with version
1.7R3_1 and needs to be updated like so:

  1. get plugin source
  2. patch `ivy.xml` and `RhinoPlugin.props` (as shown below)
  3. build

changes in `ivy.xml`:

    @@ -3,4 +3,4 @@
         <dependencies>
    -        <dependency org="org.mozilla" name="rhino" rev="1.7R3"/>
    +        <dependency org="org.mozilla" name="rhino" rev="1.7R4"/>
             <dependency org="junit" name="junit" rev="4.8.2"/>
         </dependencies>

changes in `RhinoPlugin.props`:

    @@ -4,3 +4,3 @@
     plugin.rhino.RhinoPlugin.author=http://www.mozilla.org/rhino/
    -plugin.rhino.RhinoPlugin.version=1.7R3_1
    +plugin.rhino.RhinoPlugin.version=1.7R4
     plugin.rhino.RhinoPlugin.depend.0=jedit 04.04.99.00

[jEdit]: http://jedit.org/
[CoffeeScript]: http://coffeescript.org/
[Jison]: https://zaach.github.com/jison/
[Node.js]: http://nodejs.org/