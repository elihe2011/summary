

# 1. snmp

## 1.1 安装

**Ubuntu**:

```bash
apt install snmp snmpd libsnmp-dev

vi /etc/snmp/snmpd.conf
agentaddress  127.0.0.1,[::1],192.168.3.104
view   all         included   .1
```



**CentOS**:

```bash
yum install net-snmp net-snmp-utils -y

vi /etc/snmp/snmpd.conf
view all    included  .1                               80
```



## 1.2 账号

命令 `net-snmp-create-v3-user` 参数：

-  `-ro`：用户只具有读权限
-  `-A authpass`：认证密码，至少8个字符
-  `-X privpass`：加密密码，至少8个字符
-  `-a MD5|SHA|SHA-512|SHA-384|SHA-256|SHA-224` ：认证方式
-  `-x DES|AES`：加密算法
-  `username`：用户名



```bash
# 必须先停止snmpd服务
systemctl stop snmpd

# authPriv 既认证又加密
net-snmp-create-v3-user -A eli@Auth -X eli@Priv -a MD5 -x DES eli

snmpwalk -v3 -u eli -l auth -a MD5 -A eli@Auth -X eli@Priv 192.168.3.100

# authNoPriv 认证但不加密
net-snmp-create-v3-user -A eli@Auth -a MD5 eli
snmpwalk -v3 -u eli -l authNoPriv -a MD5 -A eli@Auth 192.168.3.100

# noAuthNoPriv 不认证也不加密
net-snmp-create-v3-user eli
snmpwalk -v3 -u eli -l noAuthnoPriv 192.168.3.100

# 只读用户
net-snmp-create-v3-user -ro eli
```



## 1.3 示例

```bash
snmpbulkwalk -Cc -t 5 -r 3 -On -v 3 -u abc -l authPriv -a MD5 -A abc@Auth -x DES -X abc@Priv 192.168.3.104 1.3.6.1.2.1.25.2.3.1.3

snmpbulkwalk -Cc -t 5 -r 3 -On -v 3 -u abc -l authPriv -a MD5 -A abc@Auth -x DES -X abc@Priv 192.168.3.104 1.3.6.1.2.1.6.13.1.3

# cpu
snmpbulkwalk -Cc -t 5 -r 3 -On -v 3 -u abc -l authPriv -a MD5 -A abc@Auth -x DES -X abc@Priv 192.168.3.104 .1.3.6.1.4.1.2021.11.9.0

snmpbulkwalk -Cc -t 5 -r 3 -On -v 3 -u abc -l authPriv -a MD5 -A abc@Auth -x DES -X abc@Priv 192.168.3.104 .1.3.6.1.2.1.25.3.2

# icmp
snmpbulkwalk -Cc -t 5 -r 3 -On -v 3 -u abc -l authPriv -a MD5 -A abc@Auth -x DES -X abc@Priv 192.168.3.104 1.3.6.1.2.1.5

# disk
snmpbulkwalk -Cc -t 5 -r 3 -On -v 3 -u abc -l authPriv -a MD5 -A abc@Auth -x DES -X abc@Priv 192.168.3.104 .1.3.6.1.4.1.2021.9

# netlink
snmpbulkwalk -Cc -t 5 -r 3 -On -v 3 -u abc -l authPriv -a MD5 -A abc@Auth -x DES -X abc@Priv 192.168.3.104 .1.3.6.1.2.1.2.1


snmpbulkwalk -Cc -t 5 -r 3 -On -v 3 -u abc -l authPriv -a MD5 -A abc@Auth -x DES -X abc@Priv 192.168.3.104 .1.3.6.1.2.1.25.2.2.0
```



# 2. rsync

## 2.1 安装

```bash
# ubuntu
apt install rsync

# centos
yum install rsync
```



## 2.2 参数

```bash
Options
 -v, --verbose               increase verbosity
     --info=FLAGS            fine-grained informational verbosity
     --debug=FLAGS           fine-grained debug verbosity
     --msgs2stderr           special output handling for debugging
 -q, --quiet                 suppress non-error messages
     --no-motd               suppress daemon-mode MOTD (see manpage caveat)
 -c, --checksum              skip based on checksum, not mod-time & size
 -a, --archive               archive mode; equals -rlptgoD (no -H,-A,-X)
     --no-OPTION             turn off an implied OPTION (e.g. --no-D)
 -r, --recursive             recurse into directories
 -R, --relative              use relative path names
     --no-implied-dirs       don't send implied dirs with --relative
 -b, --backup                make backups (see --suffix & --backup-dir)
     --backup-dir=DIR        make backups into hierarchy based in DIR
     --suffix=SUFFIX         set backup suffix (default ~ w/o --backup-dir)
 -u, --update                skip files that are newer on the receiver
     --inplace               update destination files in-place (SEE MAN PAGE)
     --append                append data onto shorter files
     --append-verify         like --append, but with old data in file checksum
 -d, --dirs                  transfer directories without recursing
 -l, --links                 copy symlinks as symlinks
 -L, --copy-links            transform symlink into referent file/dir
     --copy-unsafe-links     only "unsafe" symlinks are transformed
     --safe-links            ignore symlinks that point outside the source tree
     --munge-links           munge symlinks to make them safer (but unusable)
 -k, --copy-dirlinks         transform symlink to a dir into referent dir
 -K, --keep-dirlinks         treat symlinked dir on receiver as dir
 -H, --hard-links            preserve hard links
 -p, --perms                 preserve permissions
 -E, --executability         preserve the file's executability
     --chmod=CHMOD           affect file and/or directory permissions
 -A, --acls                  preserve ACLs (implies --perms)
 -X, --xattrs                preserve extended attributes
 -o, --owner                 preserve owner (super-user only)
 -g, --group                 preserve group
     --devices               preserve device files (super-user only)
     --copy-devices          copy device contents as regular file
     --specials              preserve special files
 -D                          same as --devices --specials
 -t, --times                 preserve modification times
 -O, --omit-dir-times        omit directories from --times
 -J, --omit-link-times       omit symlinks from --times
     --super                 receiver attempts super-user activities
     --fake-super            store/recover privileged attrs using xattrs
 -S, --sparse                handle sparse files efficiently
     --preallocate           allocate dest files before writing them
 -n, --dry-run               perform a trial run with no changes made
 -W, --whole-file            copy files whole (without delta-xfer algorithm)
 -x, --one-file-system       don't cross filesystem boundaries
 -B, --block-size=SIZE       force a fixed checksum block-size
 -e, --rsh=COMMAND           specify the remote shell to use
     --rsync-path=PROGRAM    specify the rsync to run on the remote machine
     --existing              skip creating new files on receiver
     --ignore-existing       skip updating files that already exist on receiver
     --remove-source-files   sender removes synchronized files (non-dirs)
     --del                   an alias for --delete-during
     --delete                delete extraneous files from destination dirs
     --delete-before         receiver deletes before transfer, not during
     --delete-during         receiver deletes during the transfer
     --delete-delay          find deletions during, delete after
     --delete-after          receiver deletes after transfer, not during
     --delete-excluded       also delete excluded files from destination dirs
     --ignore-missing-args   ignore missing source args without error
     --delete-missing-args   delete missing source args from destination
     --ignore-errors         delete even if there are I/O errors
     --force                 force deletion of directories even if not empty
     --max-delete=NUM        don't delete more than NUM files
     --max-size=SIZE         don't transfer any file larger than SIZE
     --min-size=SIZE         don't transfer any file smaller than SIZE
     --partial               keep partially transferred files
     --partial-dir=DIR       put a partially transferred file into DIR
     --delay-updates         put all updated files into place at transfer's end
 -m, --prune-empty-dirs      prune empty directory chains from the file-list
     --numeric-ids           don't map uid/gid values by user/group name
     --usermap=STRING        custom username mapping
     --groupmap=STRING       custom groupname mapping
     --chown=USER:GROUP      simple username/groupname mapping
     --timeout=SECONDS       set I/O timeout in seconds
     --contimeout=SECONDS    set daemon connection timeout in seconds
 -I, --ignore-times          don't skip files that match in size and mod-time
 -M, --remote-option=OPTION  send OPTION to the remote side only
     --size-only             skip files that match in size
     --modify-window=NUM     compare mod-times with reduced accuracy
 -T, --temp-dir=DIR          create temporary files in directory DIR
 -y, --fuzzy                 find similar file for basis if no dest file
     --compare-dest=DIR      also compare destination files relative to DIR
     --copy-dest=DIR         ... and include copies of unchanged files
     --link-dest=DIR         hardlink to files in DIR when unchanged
 -z, --compress              compress file data during the transfer
     --compress-level=NUM    explicitly set compression level
     --skip-compress=LIST    skip compressing files with a suffix in LIST
 -C, --cvs-exclude           auto-ignore files the same way CVS does
 -f, --filter=RULE           add a file-filtering RULE
 -F                          same as --filter='dir-merge /.rsync-filter'
                             repeated: --filter='- .rsync-filter'
     --exclude=PATTERN       exclude files matching PATTERN
     --exclude-from=FILE     read exclude patterns from FILE
     --include=PATTERN       don't exclude files matching PATTERN
     --include-from=FILE     read include patterns from FILE
     --files-from=FILE       read list of source-file names from FILE
 -0, --from0                 all *-from/filter files are delimited by 0s
 -s, --protect-args          no space-splitting; only wildcard special-chars
     --address=ADDRESS       bind address for outgoing socket to daemon
     --port=PORT             specify double-colon alternate port number
     --sockopts=OPTIONS      specify custom TCP options
     --blocking-io           use blocking I/O for the remote shell
     --stats                 give some file-transfer stats
 -8, --8-bit-output          leave high-bit chars unescaped in output
 -h, --human-readable        output numbers in a human-readable format
     --progress              show progress during transfer
 -P                          same as --partial --progress
 -i, --itemize-changes       output a change-summary for all updates
     --out-format=FORMAT     output updates using the specified FORMAT
     --log-file=FILE         log what we're doing to the specified FILE
     --log-file-format=FMT   log updates using the specified FMT
     --password-file=FILE    read daemon-access password from FILE
     --list-only             list the files instead of copying them
     --bwlimit=RATE          limit socket I/O bandwidth
     --outbuf=N|L|B          set output buffering to None, Line, or Block
     --write-batch=FILE      write a batched update to FILE
     --only-write-batch=FILE like --write-batch but w/o updating destination
     --read-batch=FILE       read a batched update from FILE
     --protocol=NUM          force an older protocol version to be used
     --iconv=CONVERT_SPEC    request charset conversion of filenames
     --checksum-seed=NUM     set block/file checksum seed (advanced)
 -4, --ipv4                  prefer IPv4
 -6, --ipv6                  prefer IPv6
     --version               print version number
(-h) --help                  show this help (-h is --help only if used alone)
```



## 2.3 示例

```bash
# 免密码登录
ssh-keygen -b 4096 -t rsa
ssh-copy-id root@192.168.3.111

# 删除源文件
rsync -avz /opt/eli/output root@192.168.3.111:/opt/eli/input --remove-source-files

# 源文件被删除，同步删除目标文件(-n: dryrun)
rsync -an --delete  source destination

# 排除和包含
rsync -a --exclude=pattern_to_exclude --include=pattern_to_include  source destination

# 备份已删除的文件
rsync -avz /root/eli/ root@192.168.3.111:/root/eli/  # 同步操作
rm -rf /root/eli/abc                                 # 删除文件
rsync -a --delete --backup --backup-dir=/root/eli2 /root/eli/ root@192.168.3.111:/root/eli/  # 远程删除文件，并创建备份
```

