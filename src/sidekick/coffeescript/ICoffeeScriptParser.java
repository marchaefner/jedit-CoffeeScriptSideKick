package sidekick.coffeescript;

import java.util.List;

/**
 * Interface for CoffeeScriptParser.coffee/.js/.class
 */
interface ICoffeeScriptParser {
    void parse(String source, Object rootNode, Object config);
    String compile(String source, Object config);
}