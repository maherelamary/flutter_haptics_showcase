# Claude skills for flutter_haptics

Two Claude Code skills that teach Claude to use flutter_haptics well: what each haptic should mean, when to stay silent, and how to wire, pace and test it.

| Skill | How it runs | What it does |
|---|---|---|
| `flutter-haptics` | Automatically, whenever Claude works on Flutter UI or haptics | Reads the app's haptic tune (`docs/haptics.md`) before work and updates it after; decides which moments of a new feature get which haptic; the mental model, the per-app `AppHaptics` convention, Riverpod wiring, UX rules (when to buzz and when to stay silent), recipes for each component, API reference and testing |
| `haptics-audit` | Only when you type `/haptics-audit [path or feature]` | Audits a screen or app and reports issues by severity: setup, missing, excessive or misplaced haptics, platform checks, haptics in notifiers, unpaced drags, drift from `docs/haptics.md`. Edits, and refreshes the tune, only after you confirm. |

Both target flutter_haptics 1.0 and later (`flutter_haptics: ^1.0.0`, Flutter 3.44+).

## The haptic tune

Each app gets one `docs/haptics.md`: its haptic character, the meanings it uses and why, a moments map of every place that buzzes (or deliberately stays silent), dated decisions and device notes. Claude reads it before adding haptics to a feature and updates it in the same change, so the app's haptics stay consistent as it grows. `/haptics-audit` checks the code against it and refreshes it. The template is in `flutter-haptics/references/tune.md`; Claude creates the file the first time it is missing.

## Install

Claude Code loads skills from a project's `.claude/skills/` folder and from your personal `~/.claude/skills/`. Run these from the folder that contains this README.

For one app, committed with it so the whole team gets them:

```bash
mkdir -p <your_app>/.claude/skills
cp -R flutter-haptics haptics-audit <your_app>/.claude/skills/
```

For every project on your machine:

```bash
mkdir -p ~/.claude/skills
cp -R flutter-haptics haptics-audit ~/.claude/skills/
```

Use `ln -s` instead of `cp -R` to keep a personal install in step with this folder as the package updates.

## Keep them honest

When the flutter_haptics API changes, update `flutter-haptics/references/api.md`, and any recipe or template the change touches, in the same commit. The SDK floor in `references/setup.md` must match the package's `environment.flutter`.
