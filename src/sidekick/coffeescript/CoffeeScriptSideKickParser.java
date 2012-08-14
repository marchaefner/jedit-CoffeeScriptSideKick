package sidekick.coffeescript;

import org.gjt.sp.jedit.Buffer;

import sidekick.SideKickParser;
import sidekick.SideKickParsedData;
import errorlist.DefaultErrorSource;

/** Parser service. Starts a new ParserRunner */
public class CoffeeScriptSideKickParser extends SideKickParser {
    private ICoffeeScriptParser parser = new CoffeeScriptParser();

    public
    CoffeeScriptSideKickParser() {
        super("coffeescript");
    }

    public SideKickParsedData
    parse(Buffer buffer, DefaultErrorSource errorSource) {
        return new ParserRunner().run(parser, buffer, errorSource);
    }
}