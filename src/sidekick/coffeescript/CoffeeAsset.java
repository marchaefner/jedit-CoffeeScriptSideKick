package sidekick.coffeescript;

import java.util.Map;
import java.util.HashMap;
import javax.swing.Icon;

import sidekick.Asset;

/**
 * Asset for the SideKick tree.
 */
class CoffeeAsset extends Asset {
    private static Map<String, Icon> codeIcons;
    private static Map<String, Icon> classIcons;
    private static Icon taskIcon;

    private Icon icon = null;

    static {
        codeIcons   = new HashMap<String, Icon>();
        classIcons  = new HashMap<String, Icon>();
        initIcons();
        taskIcon = IconLoader.load("thread_view.gif");
    }

    static void initIcons() {
        codeIcons.put("",
                        IconLoader.load("methpub_obj.gif"));
        codeIcons.put("property",
                        IconLoader.load("methpub_obj.gif"));
        codeIcons.put("hidden",
                        IconLoader.load("methpri_obj.gif"));
        codeIcons.put("static",
                        IconLoader.load("methpub_obj.gif",
                                        "static_co.png"));
        codeIcons.put("constructor",
                        IconLoader.load("methpub_obj.gif",
                                        "constr_ovr.gif"));

        classIcons.put("",
                        IconLoader.load("innerclass_public_obj.gif"));
        classIcons.put("property",
                        IconLoader.load("innerclass_public_obj.gif"));
        classIcons.put("hidden",
                        IconLoader.load("innerclass_private_obj.gif"));
        classIcons.put("static",
                        IconLoader.load("innerclass_public_obj.gif",
                                        "static_co.png"));
        classIcons.put("constructor",
                        IconLoader.load("innerclass_public_obj.gif",
                                        "constr_ovr.gif"));
    }

    public CoffeeAsset(String name, String type, String qualifier) {
        super(null);

        // set icon
        if (Options.getBool("showIcons")) {
            if (type.equals("code")) {
                this.icon = codeIcons.get(qualifier);
            } else if (type.equals("class")) {
                this.icon = classIcons.get(qualifier);
            } else if (type.equals("task")) {
                this.icon = taskIcon;
            }
        }

        // add type to name
        if (Options.getBool("showType")) {
            if (type.equals("class")) {
                name = name + " <class>";
            } else if (type.equals("task")) {
                name = name + " <task>";
            }
        }

        // add prefix to name
        if (Options.getBool("showPrefix")) {
            if (qualifier.equals("hidden")) {
                name = "-" + name;
            } else if (qualifier.equals("property") || qualifier.equals("constructor")) {
                name = " " + name;
            } else if (qualifier.equals("static")) {
                name = "@" + name;
            }
        }

        // format heading
        if (type.equals("heading")) {
            name = "<html><i>" + name;
        }

        setName(name);
    }

    public String getShortString() {
        return this.name;
    }

    public String getLongString() {
        return this.name;
    }

    public Icon getIcon() {
        return this.icon;
    }
}