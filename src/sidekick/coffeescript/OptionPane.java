package sidekick.coffeescript;

import javax.swing.JCheckBox;
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

    private JCheckBox displayCodeParameters;
    private JCheckBox showErrors;

    protected void _init() {
        displayCodeParameters = addCheckBox("displayCodeParameters");
        showErrors = addCheckBox("showErrors");
    }

    protected void _save() {
        saveCheckBox("displayCodeParameters", displayCodeParameters);
        saveCheckBox("showErrors", showErrors);
    }
}
