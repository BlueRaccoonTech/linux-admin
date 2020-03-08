####################
# Holly Lotor 2020 #
####################

import random
import subprocess
import string
import sys
from os import path
import os
import platform

# We'll need to be able to write to /dev/null, so open a writable stream to /dev/null.
nullfeed = open(os.devnull, 'w')
in_ubuntu = ("ubuntu" in platform.platform().lower())
in_centos = ("centos" in platform.platform().lower())


def main():
    # Halt execution if less than two arguments.
    if len(sys.argv) < 2:
        print("Usage: batchacct.py /path/to/userfile.txt")
        exit()
    # Give the user some help.
    elif sys.argv[1] in ("help", "--help", "-h", "h"):
        print("batchacct.py - Batch Account Editor")
        print("This script only accepts one input - a file with a list of names, one per line.")
        print("i.e. batchacct.py /home/admin/filewithnames.txt")
        print("For more information regarding how the names are parsed, as well as instructions on usage of this "
              "script, please refer to the Sysadmin document, section 4 'User Management'.")
        exit()
    # Halt execution if the second argument isn't a valid file.
    elif not path.exists(sys.argv[1]):
        print("Error: File {} doesn't exist.".format(sys.argv[1]))
        exit()

    users = []
    usergroup = 0

    # Let's load the file, read-only. This will close the file when we're done with it.
    with open(sys.argv[1], "r") as user_file:
        # Process each name. This will run for each line in the file.
        for line_num, fullname in enumerate(user_file):

            # Split the line into a list of words.
            name_list = fullname.split()

            # name_list[0][0] returns the first letter of the first word.
            # name_list[-1] returns the full last word.
            # Concatenate these with a period in the middle. Ensure everything is lowercase.
            orig_username = name_list[0][0].lower() + '.' + name_list[-1].lower()
            username = orig_username

            # Initialize a variable, does_exist, with 0. This will be changed by the loop we're going to run.
            does_exist = 0

            # This following loop will return as long as we don't have a unique username, but will run at least once.
            while does_exist == 0:

                # run id with the username as an argument. If it exists, it will return without error.
                # Throw away stdout and stderr. We don't need it.
                existing = subprocess.run("/usr/bin/id -u {}".format(username),
                                          shell=True, stdout=nullfeed, stderr=nullfeed)

                # Replace the value of does_exist with the return code of id.
                does_exist = existing.returncode

                # If the username exists, id returns without error, so create new username with random nums at end.
                if does_exist == 0:
                    username = orig_username + str(random.randint(0, 99999))
                elif any(username in s[0] for s in users):
                    username = orig_username + str(random.randint(0, 99999))
                    does_exist = 1

            # Password will be 24 random characters, with each character being a letter or a number.
            password = ''.join(random.choices(string.ascii_letters + string.digits, k=24))

            # Put the username, password, and arbitrarily-selected group into a list for further processing.
            users.append([username, password, usergroup])
            usergroup += 1
            if usergroup > 5:
                usergroup = 0

    # Group 0 = admin
    # Group 1, 2 = developer
    # Group 3, 4 = staff
    # Group 5 = temp
    # Admin = Add to sudoers
    # Developer = Default to C Shell
    # Temps = Limit disk usage

    # Bail if doing a dry run.
    if (len(sys.argv) > 2) and (sys.argv[2] in ("-d", "--dry-run")):
        print("Accounts Created (DRY RUN)")
        print("=======================================")
        for newUser in users:
            if newUser[2] == 0:
                user_role = "Admin"
            elif newUser[2] < 3:
                user_role = "Developer"
            elif newUser[2] < 5:
                user_role = "Staff"
            elif newUser[2] == 5:
                user_role = "Temp"
            else:
                # We should literally never get here, but if I don't add it, we would.
                # Hence why I'm adding it lol
                user_role = "Invalid"
            print("{user} | {userpass} | {group}".format(user=newUser[0], userpass=newUser[1], group=user_role))
    else:
        # Aw yeah, it's big "plz don't screw this up" time.
        print("Accounts Created")
        print("=======================================")
        for newUser in users:
            if newUser[2] == 0:
                user_role = "administrators"
                user_skeleton = "/etc/skel-0"
                user_shell = "/bin/bash"
            elif newUser[2] < 3:
                user_role = "developer"
                user_skeleton = "/etc/skel-2"
                user_shell = "/bin/csh"
            elif newUser[2] < 5:
                user_role = "staff"
                user_skeleton = "/etc/skel-4"
                user_shell = "/bin/bash"
            elif newUser[2] == 5:
                user_role = "temp"
                user_skeleton = "/etc/skel-5"
                user_shell = "/bin/bash"
            else:
                # We should literally never get here, but if I don't add it, we would.
                # Hence why I'm adding it lol
                user_role = "Invalid"
                print("An internal error has occurred and user {} could not be added.".format(newUser[0]))
            if user_role != "Invalid":
                user_creation = subprocess.run("/usr/sbin/useradd -m -k {skelly} -G {group} -s {usrshell} {username}"
                                               .format(username=newUser[0], skelly=user_skeleton, group=user_role,
                                                       usrshell=user_shell),
                                               shell=True, stdout=nullfeed, stderr=nullfeed)
                if user_creation.returncode != 0:
                    print("An error occurred trying to add user {}".format(newUser[0]))
                else:
                    password_add = subprocess.run("echo '{username}:{userpass}' | /usr/sbin/chpasswd".format(
                                                  username=newUser[0], userpass=newUser[1]),
                                                  shell=True, stdout=nullfeed, stderr=nullfeed)
                    if password_add.returncode != 0:
                        print("An error occurred trying to assign password to user {}. "
                              "This must be done manually.".format(newUser[0]))
                    if user_role == "temp":
                        # Add quota.
                        if in_ubuntu:
                            # Work with quotatool here
                            quota_create = subprocess.run("/usr/sbin/quotatool -u {usern} -b -q 25Mb -l 30Mb /".format(
                                                          usern=newUser[0]), shell=True, stdout=nullfeed,
                                                          stderr=nullfeed)
                            failed_quota = False
                        elif in_centos:
                            # Work with xfs quota here
                            quota_create = subprocess.run("/usr/sbin/xfs_quota -x -c "
                                                          "'limit -u bsoft=25m bhard=30m {}' /home".format(newUser[0]),
                                                          shell=True, stdout=nullfeed, stderr=nullfeed)
                            failed_quota = False
                        else:
                            print("Can't determine which OS you're on!")
                            failed_quota = True
                        if failed_quota or (quota_create.returncode != 0):
                            print("Failed to create quota for user {}".format(newUser[0]))
            print("{user} | {userpass} | {group}".format(user=newUser[0], userpass=newUser[1], group=user_role))


# Ensure this  is being run as a script, not imported as a module.
if __name__ == "__main__":
    main()
else:
    print("ERROR: This is a script, not a module.")
    print("Usage: batchacct.py /path/to/userfile.txt")
