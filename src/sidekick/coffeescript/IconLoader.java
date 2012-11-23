package sidekick.coffeescript;

import java.util.Map;
import java.util.HashMap;
import java.awt.Graphics;
import java.awt.Image;
import java.awt.image.BufferedImage;
import javax.swing.ImageIcon;

import org.gjt.sp.util.Log;
import eclipseicons.EclipseIconsPlugin;

/**
 * Utility class for loading icons from the EclipseIcons plugin.
 */
class IconLoader {
    private static Map<String, ImageIcon> iconsCache = new HashMap<String, ImageIcon>();

    static ImageIcon load(String iconFile) {
        ImageIcon icon = iconsCache.get(iconFile);
        if (icon == null) {
            try {
                icon = EclipseIconsPlugin.getIcon(iconFile);
                iconsCache.put(iconFile, icon);
            } catch (Exception ex) {
                Log.log(Log.ERROR, CoffeeScriptSideKickParser.class,
                        "Failed to load \"" + iconFile + "\" from EclipseIcons",
                        ex);
            }
        }
        return icon;
    }

    /**
     * Load icon and draw overlay on the upper right corner.
     * Assumes that the icon is 16px x 16px and the overlay icon is 7px x 7px.
     */
    static ImageIcon load(String iconFile, String overlayFile) {
        ImageIcon icon = load(iconFile);
        if (icon == null) {
            return null;
        }
        ImageIcon overlayIcon = load(overlayFile);
        if (overlayIcon == null) {
            return null;
        }

        BufferedImage iconImage = new BufferedImage(16, 16, BufferedImage.TYPE_INT_ARGB);
        Graphics g = iconImage.getGraphics();
        g.drawImage(icon.getImage(), 0, 0, null);
        g.drawImage(overlayIcon.getImage(), 9, 0, null);
        g.dispose();
        return new ImageIcon(iconImage);
    }
}
