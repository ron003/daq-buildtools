#!/usr/bin/env python3

import sys
import yaml
import argparse


def get_field(fman, fkey):
    try:
        fvalue = fman[fkey]
    except KeyError:
        print("Field {} does not exist in the manifest file!".format(fkey))
    return fvalue


def parse_manifest_file(fname):
    with open(fname, 'r') as stream:
        try:
            fman = yaml.safe_load(stream)
        except yaml.YAMLError as exc:
            print(exe)
    return fman


def merge_dict(y1, y2):
    for key, value in y2.items():
        if key in y1:
            if type(value) is dict:
                merge_dict(y1[key], y2[key])
            elif type(value) is list:
                y1[key].extend(y2[key])
            else:
                y1[key] = y2[key]
        else:
            y1[key] = y2[key]
    return


def merge_dict_list(listd):
    if listd is None:
        return
    tags = list(listd[0].keys())
    mlistd = [[] for x in tags]
    for i in listd:
        if i[tags[0]] not in mlistd[0]:
            for j in range(len(tags)):
                mlistd[j].append(i[tags[j]])
        else:
            idx = mlistd[0].index(i[tags[0]])
            for j in range(1, len(tags)):
                mlistd[j][idx] = i[tags[j]]
    listd = [ {tags[k]:mlistd[k][i] for k in range(len(tags))} \
        for i in range(len(mlistd[0])) ]
    return listd


def merge_manifest_files(fnames):
    """Merge dictionaries in the list, elements with higher index take 
    precedence; fnames looks like [running, develop, user]"""
    fman = {}
    for i in fnames:
        merge_dict(fman, parse_manifest_file(i))

    for i in ["external_deps", "src_pkgs", "prebuilt_pkgs"]:
        fman[i] = merge_dict_list(fman[i])

    return fman


def cmd_external_setup(fman, user=False):
    """return line seperated UPS setup commands to be used in 'eval' in bash
    scripts"""
    return setup_string


def cmd_prebuilt_setup(fman, user=False):
    """return line seperated UPS setup commands to be used in 'eval' in bash
    scripts"""
    return setup_string


def cmd_git_clone(fman, user=False):
    """return line seperated git clone commands for DAQ source packages"""
    return setup_string


#fnames = ["run.yml", "develop.yml", "user.yml"]
#fman = merge_manifest_files(fnames)
#print(fman)
#print(yaml.dump(fman, default_flow_style=False, sort_keys=False))

###MAIN FUNCTION#########

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
            prof='parse-manifest.py',
            description="Parse DUNE DAQ release manifest files.",
            epilog="Questions and comments to dingpf@fnal.gov")
    parser.add_argument('--setup-external', action='store_true',
            help='''Generate line separated bash commands of setting up UPS
            products for external dependencies;''')
    parser.add_argument('--setup-prebuilt', action='store_true',
            help='''generate line separated bash commands of setting up ups
            products for prebuilt daq packages;''')
    parser.add_argument('--git-checkout', action='store_true',
            help='''generate line separated bash commands of checking out DAQ
            source packages from GitHub;''')
    parser.add_argument('-r', '--release', default='development',
            help="set the DAQ release to use;")
    parser.add_argument('-p', '--path-to-manifest', default='./daq-release',
            help="set the path to DAQ release manifest files;")
    parser.add_argument('-u', '--users-manifest',
            default='./daq-release/user.yaml',
            help="set the path to user's manifest files;")

    args = parser.parse_args()

