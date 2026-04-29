# tud-processor-design-project

Group 24 personal workspace for **CESE4040 Processor Design Project** (TU Delft, Q4 2025-2026).

This repo holds our personal helpers, notes, and the course PDFs. The course-tracked
sources (RTL, C software) live in a **separate gitlab repo** that you clone into
`pdp-project-24/` — see step 3 below.

> Course context, deadlines, baseline numbers, etc. → `CLAUDE.md`
> Per-task progress log → `PROGRESS.md`, `BASELINE.md`, `PROFILING.md`

## Layout

```
.
├── CLAUDE.md                     # primary project context (read this first)
├── BASELINE.md                   # measured baseline numbers
├── PROFILING.md                  # profiling notes
├── PROGRESS.md                   # running task log
├── credentials.example.txt       # copy → credentials.txt and fill in
├── scripts/                      # helpers: server SSH, mount, Vivado, X2Go, fetch
│   ├── _lib.sh                       # shared: loads credentials
│   ├── setup-server-auth.sh          # one-time: push your SSH pubkey to the server
│   ├── connect-server.sh             # ssh into the server
│   ├── mount-server.sh               # sshfs-mount server $HOME at ~/pdp-server-mnt
│   ├── umount-server.sh
│   ├── launch-vivado.sh              # ssh -Y → Vivado GUI (or --batch-sim)
│   ├── launch-x2go.sh                # full MATE desktop via X2Go
│   └── fetch-from-server.sh          # scp artifacts (e.g. bitstream) to ./artifacts/
├── pdp-project-24/               # NOT in this repo — clone separately (step 3)
└── *.pdf                         # course manuals (Brightspace mirror)
```

## Onboarding (new teammate)

### 1. Clone

```bash
git clone git@github.com:danieltyukov/tud-processor-design-project.git
cd tud-processor-design-project
```

### 2. Set up credentials

```bash
cp credentials.example.txt credentials.txt
chmod 600 credentials.txt
$EDITOR credentials.txt
```

Fill in:

- `PDP_SERVER_PASS` — the shared group-account password (Brightspace / Teams group 24).
- `PDP_SSH_KEY` — path to **your** SSH private key (generate one if you don't have it: `ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_tudelft`).
- `PDP_GITLAB_TOKEN` — **your own** gitlab Personal Access Token (create at <https://gitlab.ewi.tudelft.nl/-/profile/personal_access_tokens>, scopes `read_repository` + `write_repository`). Needed only on the server side; not for cloning the gitlab repo from your laptop.

`credentials.txt` is `.gitignore`d — never commit it.

### 3. Clone the gitlab subrepo

The course-tracked RTL + C sources live in a separate gitlab repo. Clone it into the
`pdp-project-24/` subdirectory of this workspace:

```bash
git clone git@gitlab.ewi.tudelft.nl:qce/computer-engineering/computer-engineering/courses/pdp-processor-design-project/student-work/2025-2026/pdp-project-24.git
```

Requires SSH-key access to `gitlab.ewi.tudelft.nl` (add your pubkey at <https://gitlab.ewi.tudelft.nl/-/profile/keys>).

### 4. Push your SSH pubkey to the dev server (one-time)

```bash
./scripts/setup-server-auth.sh        # uses sshpass + the password from credentials.txt
```

After this, every other script uses passwordless pubkey auth.

### 5. Smoke test

```bash
./scripts/connect-server.sh 'echo hello from $(hostname); ls ~/pdp-project | head'
```

You should see the server hostname and the gitlab repo contents on the server.

## Common workflows

| What | Command |
|------|---------|
| SSH into server | `./scripts/connect-server.sh` |
| Run a one-shot remote command | `./scripts/connect-server.sh 'ls ~/pdp-project'` |
| Mount server $HOME locally | `./scripts/mount-server.sh` (then browse `~/pdp-server-mnt/`) |
| Launch Vivado GUI (X11 forward) | `./scripts/launch-vivado.sh` |
| Headless baseline simulation | `./scripts/launch-vivado.sh --batch-sim` |
| Full MATE desktop (smoother) | `./scripts/launch-x2go.sh` |
| Pull bitstream + .hwh to laptop | `./scripts/fetch-from-server.sh --bitstream` |

## Security notes

- **Never commit `credentials.txt`.** It's gitignored, but double-check `git status` before every push.
- **Never share your gitlab PAT.** Each teammate creates their own.
- The dev-server account `cese4040-24` is shared across all 4 of us — be considerate (don't kill X2Go sessions you don't recognize, log out via the GUI).
- This repo is **private**. If we ever make it public, scrub `CLAUDE.md` first (it mentions internal hostnames, the shared username, and Brightspace group context).
