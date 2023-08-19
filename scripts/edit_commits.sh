#!/bin/bash

if git filter-repo -h &>/dev/null; then
    ORIGIN_BEFORE="$(git remote get-url origin)" # git filter-repo deletes this to avoid accidental pushes
    git filter-repo -f \
        --mailmap "$SCRIPT_ROOT"/data/shared/mailmap.edit_commits \
        --replace-text "$SCRIPT_ROOT"/data/shared/replace.edit_commits \
        --replace-message "$SCRIPT_ROOT"/data/shared/replace.edit_commits
    git remote add origin "$ORIGIN_BEFORE" # so we add it again
else
    echo '==> The extension `git filter-branch` is not installed. It’s use is recommended by the git project. https://github.com/newren/git-filter-repo/'
    # for some reason we have to execute this twice for everything to be pruned
    export FILTER_BRANCH_SQUELCH_WARNING=1
    I=2
    while [ "$I" -gt 0 ]; do
        I=$((I-1))
        git filter-branch -f -d .git-rewrite"$I" \
            --env-filter "$(cat "$SCRIPT_ROOT"/data/shared/legacy.edit_commits)" \
            --tag-name-filter cat -- --branches --tags --all
        git reflog expire --expire=now --expire-unreachable=now --all;
        git gc --prune=now
    done
fi
