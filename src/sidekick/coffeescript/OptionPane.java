package sidekick.coffeescript;

import javax.swing.JCheckBox;
import javax.swing.JLabel;
import javax.swing.Box;
import javax.swing.BorderFactory;
import org.gjt.sp.jedit.AbstractOptionPane;

public class OptionPane extends AbstractOptionPane {
    public OptionPane() {
        super("coffeescript");
    }

    private JCheckBox addCheckBox(String name) {
        JCheckBox checkbox = new JCheckBox(Options.getLabel(name));
        checkbox.getModel().setSelected(Options.getBool(name));
        addComponent(checkbox);
        return checkbox;
    }

    private void saveCheckBox(String name, JCheckBox checkBox) {
        Options.setBool(name, checkBox.getModel().isSelected());
    }

    private JCheckBox showErrors;
    private JCheckBox displayCodeParameters;
    private JCheckBox showDoccoHeadings;
    private JCheckBox showIcons;
    private JCheckBox showPrefix;
    private JCheckBox showType;

    protected void _init() {
        setBorder(BorderFactory.createEmptyBorder(6, 6, 6, 6));
        showErrors = addCheckBox("showErrors");
        addComponent(Box.createVerticalStrut(12));
        addComponent(new JLabel("<html><b>Display Options"));
        addComponent(Box.createVerticalStrut(4));
        displayCodeParameters = addCheckBox("displayCodeParameters");
        showDoccoHeadings = addCheckBox("showDoccoHeadings");
        showIcons = addCheckBox("showIcons");
        showPrefix = addCheckBox("showPrefix");
        showType = addCheckBox("showType");
    }

    protected void _save() {
        saveCheckBox("showErrors", showErrors);
        saveCheckBox("displayCodeParameters", displayCodeParameters);
        saveCheckBox("showDoccoHeadings", showDoccoHeadings);
        saveCheckBox("showIcons", showIcons);
        saveCheckBox("showPrefix", showPrefix);
        saveCheckBox("showType", showType);
    }
}
