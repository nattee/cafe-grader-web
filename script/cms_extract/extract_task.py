#!/usr/bin/env python3
"""Extract ONE task from a live CMS instance as a portable bundle.

Runs ON the CMS server as the cms user, streamed over ssh (never installed):

    ssh HOST sudo -n -u cms /home/cms/cms_venv/bin/python3 - TASKNAME \
        < script/cms_extract/extract_task.py > bundle.tar

Wraps the official cmsDumpExporter for ALL serialization (structure-only,
no submissions / user-tests / print jobs; the full-instance structure dump
measured ~45 s on c2, which is fine per clone, so no -c contest scoping is
needed). Adds only what official tooling cannot do:
  * single-task subtree filter -- Users/Participations (password hashes)
    never enter the bundle and never leave the server
  * digest-selective blob fetch via cms FileCacher (blobs live in the DB;
    there is no on-disk file store on c2)

stdout: tar stream of bundle/ (task.json + files/<digest>)
stderr: progress log            exit: 0 ok, 2 usage, 3 task not found
Read-only against CMS. Work dir is 0700 under /tmp and removed on exit.
Consumed by app/engine/converters/cms_dump_converter.rb (bundle_version 1).
"""
import json
import os
import shutil
import subprocess
import sys
import tarfile
import tempfile

BUNDLE_VERSION = 1
VENV = os.environ.get("CMS_VENV", "/home/cms/cms_venv")


def log(msg):
    sys.stderr.write(msg + "\n")
    sys.stderr.flush()


def build_subtree(objects, task_name):
    """Return (task_id, subtree, digests) for the named task.

    Pure function over the dump's object map (no CMS imports) so it is
    unit-testable off-server. Only the task row and its statements,
    attachments, datasets, managers, and testcases enter the subtree.
    """
    task_ids = [k for k, v in objects.items()
                if v.get("_class") == "Task" and v.get("name") == task_name]
    if not task_ids:
        return None, None, None
    tid = task_ids[0]
    task = objects[tid]
    subtree = {tid: task}
    digests = []
    for sid in task.get("statements", {}).values():
        subtree[str(sid)] = objects[str(sid)]
        digests.append(objects[str(sid)]["digest"])
    for aid in task.get("attachments", {}).values():
        subtree[str(aid)] = objects[str(aid)]
        digests.append(objects[str(aid)]["digest"])
    for did in task.get("datasets", []):
        ds = objects[str(did)]
        subtree[str(did)] = ds
        for mid in ds.get("managers", {}).values():
            subtree[str(mid)] = objects[str(mid)]
            digests.append(objects[str(mid)]["digest"])
        for tcid in ds.get("testcases", {}).values():
            tc = objects[str(tcid)]
            subtree[str(tcid)] = tc
            digests.append(tc["input"])
            digests.append(tc["output"])
    return tid, subtree, digests


def main():
    if len(sys.argv) != 2:
        log("usage: extract_task.py <task_name>")
        return 2
    task_name = sys.argv[1]
    work = tempfile.mkdtemp(prefix="cms_extract_")
    os.chmod(work, 0o700)
    try:
        # The exporter/FileCacher may create relative cache dirs -> keep them
        # inside the 0700 work dir.
        os.chdir(work)
        dump_dir = os.path.join(work, "dump")  # exporter refuses existing dirs
        log("[extract] official cmsDumpExporter (structure only, no submissions) ...")
        subprocess.run(
            [os.path.join(VENV, "bin", "cmsDumpExporter"),
             "-F", "-S", "-U", "-P", dump_dir],
            check=True, stdout=sys.stderr, stderr=sys.stderr)
        with open(os.path.join(dump_dir, "contest.json")) as f:
            dump = json.load(f)
        dump_version = dump.get("_version")
        objects = {k: v for k, v in dump.items() if not k.startswith("_")}
        tid, subtree, digests = build_subtree(objects, task_name)
        if tid is None:
            names = sorted(v["name"] for v in objects.values()
                           if v.get("_class") == "Task")
            log("ERROR: task '%s' not found. %d tasks exist, e.g.: %s"
                % (task_name, len(names), ", ".join(names[:10])))
            return 3
        log("[extract] task id %s: %d objects, %d unique blobs"
            % (tid, len(subtree), len(set(digests))))

        bundle = os.path.join(work, "bundle")
        files_dir = os.path.join(bundle, "files")
        os.makedirs(files_dir)
        with open(os.path.join(bundle, "task.json"), "w") as f:
            json.dump({"bundle_version": BUNDLE_VERSION,
                       "dump_version": dump_version,
                       "task_id": tid,
                       "objects": subtree},
                      f, ensure_ascii=False, indent=1)

        log("[extract] fetching blobs via FileCacher ...")
        from cms.db.filecacher import FileCacher  # venv import; server only
        fc = FileCacher()
        for dig in sorted(set(digests)):
            src = fc.get_file(dig)
            with open(os.path.join(files_dir, dig), "wb") as out:
                shutil.copyfileobj(src, out)
            src.close()

        log("[extract] streaming bundle to stdout ...")
        with tarfile.open(fileobj=sys.stdout.buffer, mode="w|") as tar:
            tar.add(bundle, arcname="bundle")
        sys.stdout.buffer.flush()
        log("[extract] done")
        return 0
    finally:
        shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
