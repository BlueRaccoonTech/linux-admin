#!/usr/bin/python3
# Holly Lotor Montalvo 2020
# userint.py
# A basic script to check for add/removal of users with some basic integrity checking.
# Designed to be run as root.

# I was honestly hoping AIDE would be good for this, but unfortunately it only detects
# that the file has changed - not what exactly within the file has changed.

import os.path
import hashlib
import subprocess
import datetime


def get_passwd():
    # Read the contents of /etc/passwd into a variable.
    with open("/etc/passwd") as file:
        etc_passwd = file.read()
    # Return the variable.
    return etc_passwd


def write_passwd(etc_passwd):
    with open("/var/lib/pint.data", "w") as file:
        file.write(etc_passwd)


def check_pint_exists():
    # I don't know if I really even need this variable, but eh.
    return os.path.isfile("/var/lib/pint.data") and os.path.isfile("/var/lib/pint.hash")


def create_hash(passwd_file):
    # Get the hash of the passwd file contents.
    hasher = hashlib.sha256()
    hasher.update(passwd_file.encode('utf-8'))
    # Write the hash into a file.
    with open("/var/lib/pint.hash", "w") as file:
        file.write(hasher.hexdigest())


def compare_hash_to_file(passwd_file):
    # Get the hash of the passwd file contents.
    hasher = hashlib.sha256()
    hasher.update(passwd_file.encode('utf-8'))
    # Read the saved hash.
    with open("/var/lib/pint.hash") as file:
        hash = file.read()
    # Compare the two and return if they match or not.
    return hasher.hexdigest() == hash


def passwd_pint_diff():
    subprocess.call(["diff", "/etc/passwd", "/var/lib/pint.data"])


def main():
    print(datetime.datetime.now())
    etc_passwd = get_passwd()
    if check_pint_exists() is False:
        print("Integrity files don't exist. Creating, then exiting...")
        write_passwd(etc_passwd)
        create_hash(etc_passwd)
        print("--------------------------------------------------------")
        exit(10)
    if compare_hash_to_file(etc_passwd):
        print("No changes to /etc/passwd detected.")
        print("--------------------------------------------------------")
        exit(0)
    else:
        passwd_pint_diff()
        print("Changes found, running diff...", end="\n\n")
        write_passwd(etc_passwd)
        create_hash(etc_passwd)
        print("--------------------------------------------------------")
        exit(1)


if __name__ == '__main__':
    main()

