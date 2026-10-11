# star-wars-terminal: Jedi prompt for fish.
# Installed as ~/.config/fish/conf.d/star-wars-terminal.fish by the installer.

set -q SWT_HOME; or set -gx SWT_HOME $HOME/.config/star-wars-terminal
test -d $HOME/.local/bin; and fish_add_path -g $HOME/.local/bin

# Lightsaber color. Red is kept for failed commands, so it isn't offered here.
set -g _swt_sabers blue green purple yellow white
function _swt_rgb
    switch $argv[1]
        case green; echo "166;227;161"
        case purple; echo "203;166;247"
        case yellow; echo "249;226;175"
        case white; echo "239;241;245"
        case '*'; echo "137;180;250"
    end
end
if test -f $SWT_HOME/saber.txt
    set -l saved (string trim (head -n 1 $SWT_HOME/saber.txt))
    contains -- $saved $_swt_sabers; and set -gx JEDI_SABER $saved
end

# Usage: saber green   (no argument shows the current color and the options)
function saber
    if test (count $argv) -eq 0
        set -l current blue
        set -q JEDI_SABER; and set current $JEDI_SABER
        echo "Current saber: $current. Options: blue, green, purple, yellow, white"
        return 0
    end
    set -l pick (string lower -- $argv[1])
    if not contains -- $pick $_swt_sabers
        echo "saber: \"$argv[1]\" isn't a saber color. Options: blue, green, purple, yellow, white" >&2
        return 1
    end
    set -gx JEDI_SABER $pick
    echo $pick > $SWT_HOME/saber.txt
end

# Prompt
if status is-interactive; and command -q oh-my-posh
    oh-my-posh init fish --config $SWT_HOME/jedi.omp.json | source
end

# A line from the Jedi Archives for each new session
if status is-interactive; and test -f $SWT_HOME/shell/quotes.txt
    set -l lines (string match -- '*|*' < $SWT_HOME/shell/quotes.txt)
    if test (count $lines) -gt 0
        set -l parts (string split -m 1 '|' -- $lines[(random 1 (count $lines))])
        set -l saber blue
        set -q JEDI_SABER; and set saber $JEDI_SABER
        printf '\e[38;2;%sm\e[0m \e[38;2;166;173;200m%s\e[0m \e[38;2;108;112;134m- %s\e[0m\n' (_swt_rgb $saber) $parts[1] $parts[2]
    end
end
