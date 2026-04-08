#!/bin/bash
# paste_as_symlink.sh — Create symlinks in target directory from clipboard files
# Called by PasteAsSymLink.workflow Quick Action
# Usage: paste_as_symlink.sh <target_directory>

LOG="/tmp/paste_symlink_debug.log"
echo "$(date) — paste_as_symlink.sh invoked" >> "$LOG"
echo "  args: $*" >> "$LOG"
echo "  HOME=$HOME" >> "$LOG"

target_dir="$1"

if [ ! -d "$target_dir" ]; then
    echo "  ERROR: not a directory: $target_dir" >> "$LOG"
    osascript -e 'display notification "Target is not a directory" with title "Paste as Sym Link" sound name "Basso"'
    exit 1
fi

# Get file paths from clipboard via JXA
# Tries NSFilenamesPboardType first, then public.file-url
sources=$(osascript -l JavaScript -e '
ObjC.import("AppKit");
var pb = $.NSPasteboard.generalPasteboard;

// Method 1: NSFilenamesPboardType (classic Finder copy)
var filenames = pb.propertyListForType("NSFilenamesPboardType");
if (filenames && filenames.count > 0) {
    var out = [];
    for (var i = 0; i < filenames.count; i++) {
        out.push(ObjC.unwrap(filenames.objectAtIndex(i)));
    }
    out.join("\n");
} else {
    // Method 2: public.file-url (modern)
    var urlStr = ObjC.unwrap(pb.stringForType("public.file-url"));
    if (urlStr && urlStr.indexOf("file://") === 0) {
        decodeURIComponent(urlStr.substring(7));
    } else {
        "";
    }
}
' 2>/dev/null)

echo "  sources='$sources'" >> "$LOG"

if [ -z "$sources" ]; then
    echo "  ERROR: no sources found on clipboard" >> "$LOG"
    osascript -e 'display notification "No file in clipboard. Copy a file first (Cmd+C)." with title "Paste as Sym Link" sound name "Basso"'
    exit 1
fi

count=0
errors=0
IFS=$'\n'
for source in $sources; do
    source=$(echo "$source" | sed 's:/*$::')
    if [ -z "$source" ] || [ ! -e "$source" ]; then
        continue
    fi
    name=$(basename "$source")
    link_path="${target_dir%/}/${name}"
    if [ -e "$link_path" ]; then
        osascript -e "display notification \"${name} already exists in target\" with title \"Paste as Sym Link\" sound name \"Basso\""
        errors=$((errors + 1))
        continue
    fi
    ln -s "$source" "$link_path"
    if [ $? -eq 0 ]; then
        count=$((count + 1))
    else
        errors=$((errors + 1))
    fi
done

if [ $count -gt 0 ]; then
    dir_name=$(basename "$target_dir")
    osascript -e "display notification \"Created ${count} symlink(s) in ${dir_name}\" with title \"Paste as Sym Link\""
elif [ $errors -eq 0 ]; then
    osascript -e 'display notification "No valid files found in clipboard" with title "Paste as Sym Link" sound name "Basso"'
fi
