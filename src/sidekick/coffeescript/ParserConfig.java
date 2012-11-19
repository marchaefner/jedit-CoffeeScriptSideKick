package sidekick.coffeescript;

import javax.swing.tree.DefaultMutableTreeNode;

import org.gjt.sp.util.Log;
import org.gjt.sp.jedit.Buffer;

import errorlist.DefaultErrorSource;
import errorlist.ErrorSource;

/** Configuration object for the parser, providing options and callbacks for
    TreeNode construction, error reporting and logging.
 */
public class ParserConfig {
    public boolean showErrors;
    public boolean displayCodeParameters;
    public boolean isCakefile;
    public int line = 0;

    private Buffer buffer;
    private DefaultErrorSource errorSource;

    ParserConfig(Buffer buffer, DefaultErrorSource errorSource) {
        this.buffer = buffer;
        this.errorSource = errorSource;
        this.showErrors = Options.getBool("showErrors");
        this.displayCodeParameters = Options.getBool("displayCodeParameters");
        this.isCakefile = buffer.getName().equals("Cakefile");
    }

    public void
    logError(String message) {
        Log.log(Log.ERROR, CoffeeScriptSideKickParser.class, message);
    }

    public void
    reportError(Integer line, String message) {
        if (line == null) {
            line = Integer.MAX_VALUE;
        }
        this.errorSource.addError(
            new DefaultErrorSource.DefaultError(this.errorSource,
                                                ErrorSource.ERROR,
                                                this.buffer.getPath(),
                                                line,
                                                0, 0,
                                                message));
    }

    public DefaultMutableTreeNode
    makeTreeNode(String name, String type, int firstLine, int lastLine) {
        if (type.equals("hidden")) {
            name = "-" + name;
        } else if (type.equals("property")) {
            name = " " + name;
        }
        CoffeeAsset asset = new CoffeeAsset(name);
        asset.setStart(
            this.buffer.createPosition(
                this.buffer.getLineStartOffset(firstLine)));
        asset.setEnd(
            this.buffer.createPosition(
                this.buffer.getLineEndOffset(lastLine) - 1));

        return new DefaultMutableTreeNode(asset);
    }
}
