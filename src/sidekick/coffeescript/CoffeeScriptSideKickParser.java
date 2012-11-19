package sidekick.coffeescript;

import org.gjt.sp.jedit.Buffer;

import sidekick.SideKickParser;
import sidekick.SideKickParsedData;
import errorlist.DefaultErrorSource;

public class CoffeeScriptSideKickParser extends SideKickParser {
    public
    CoffeeScriptSideKickParser() {
        super("coffeescript");
    }

    public SideKickParsedData
    parse(Buffer buffer, DefaultErrorSource errorSource) {
        ICoffeeScriptParser parser = new CoffeeScriptParser();
        SideKickParsedData parsedData = new SideKickParsedData(buffer.getName());
        parser.parse(   buffer.getText(),
                        parsedData.root,
                        new ParserConfig(buffer, errorSource));
        return parsedData;
    }
}