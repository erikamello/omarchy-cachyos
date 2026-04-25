# Place in ~/.claude/skills since all tools populate from there as well as their own sources
mkdir -p ~/.claude/skills

SOURCE="$OMARCHY_PATH/default/omarchy-skill"
TARGET="$HOME/.claude/skills/omarchy"

if [[ -e $TARGET && ! -L $TARGET ]]; then
  mv "$TARGET" "$TARGET.bak.$(date +%s)"
fi

ln -sfn "$SOURCE" "$TARGET"
