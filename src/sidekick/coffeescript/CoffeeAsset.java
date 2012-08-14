package sidekick.coffeescript;

import javax.swing.Icon;
import sidekick.Asset;

import org.gjt.sp.util.Log;

/** A simple Asset that's not abstract. */
public class CoffeeAsset extends Asset {
    public CoffeeAsset(String name) {
        super(name);
    }

    public String getShortString() {
        return this.name;
    }

    public String getLongString() {
        return this.name;
    }

    public Icon getIcon() {
        return null;
    }
}