# silly([blog](http://blog.gotocoding.com/?p=446))
--------
##depend

- sudo apt-get install libreadline-dev(debain)
- yum install readline-devel(centos)

##build

- make linux
- make macosx

##run
    ./silly <configfile>

##field of configfile

- daemon, 1 --> run as daemon, 0 --> normal
- bootstrap, lua entry
- lualib_path, will append the package.path (in luaVM)
- lualib_cpath, will append the package.cpath (int luaVM)
