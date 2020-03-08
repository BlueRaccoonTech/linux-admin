####################
# Holly Lotor 2020 #
####################

import random
import subprocess
import string
import sys
from os import path
import os

# We'll need to be able to write to /dev/null, so open a writable stream to /dev/null.
nullfeed = open(os.devnull, 'w')


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

            # Password will be 16 random characters, with each character being a letter, a number, or punctuation.
            password = ''.join(random.choices(string.ascii_letters + string.digits + string.punctuation, k=16))

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
    if sys.argv[2] in ("-d", "--dry-run"):
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

# Ensure this  is being run as a script, not imported as a module.
if __name__ == "__main__":
    main()
else:
    print("ERROR: This is a script, not a module.")
    print("Usage: batchacct.py /path/to/userfile.txt")
