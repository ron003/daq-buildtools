
echo "Test instructions at https://github.com/DUNE-DAQ/appfwk/wiki/Compiling-and-running as of Oct-2-2020"

curl -O https://raw.githubusercontent.com/DUNE-DAQ/daq-buildtools/develop/bin/dbt-init.sh
chmod +x dbt-init.sh
./dbt-init.sh

. ./dbt-setup-build-environment  # Only needs to be done once in a given shell
cd sourcecode
git clone https://github.com/DUNE-DAQ/appfwk.git
cd ..
./build_daq_software.sh --install


