package sidekick.coffeescript;

/**
 * Interface for CoffeeScriptParser.coffee/.js/.class
 */
interface ICoffeeScriptParser {
    void parse(String source, Object rootNode, Object config);
    String compile(String source, Object config);
}