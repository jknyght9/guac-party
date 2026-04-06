Port 22
PubkeyAuthentication yes
PasswordAuthentication no
AuthorizedKeysFile .ssh/authorized_keys

# If this is not here SSH will not work :(
UsePAM yes
PermitRootLogin yes
MaxAuthTries 10
MaxSessions 10

ListenAddress ${nomad_ip}