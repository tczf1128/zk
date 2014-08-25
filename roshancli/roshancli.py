#!/usr/bin/env python

import os
import sys
import json
from roshan import Roshan
from conf import config
import traceback

__usage__ = """Usage: %(argv0)s command path machines acls

Example:
    %(argv0)s load /sandbox/noah machine_sample acl_sample
        add nodes like 'host_port' from 'machine_sample' with acls from 'acl_sample' under '/sandbox/noah'
    %(argv0)s list /sandbox
        list subtree of /sandbox
    %(argv0)s delete /sandbox key
        delete children of /sandbox whose name contain key
    %(argv0)s show /sandbox/noah
        get the data of a node
"""

_version_ = "0.0.0.3"

def _print_prefix(level):
    while level > 0:
            level-=1
            print "\t",
    print "+",        

def _parse_acl_file(aclsfile):
    """load /sandbox/noah hosts acls"""
    acls = open(aclsfile).read()
    return acls


def _parse_host_file(hostsfile):
    with open(hostsfile) as hosts:
        for host in hosts:
            if host.startswith('#') or ':' not in host:
                continue
            ip, port = host[:-1].split(':')
            ip = ip.strip()
            port = port.strip()
            yield (ip, port)


def load(path, hostsfile, aclsfile):
    roshan = Roshan(*config['addr'])
    if 'incorrect' in roshan.login(*config['account']):
        print 'Wrong Username/Email and password combination.'
        return -1
    acls = _parse_acl_file(aclsfile)
    for ip, port in _parse_host_file(hostsfile):
        newnode = os.path.join(path, '%s_%s'%(ip, port))
        node_data = dict(ip=ip, port=port)
        ret = roshan.add_node(newnode, acl=acls, data=json.dumps(node_data))
        if ret.get('status', 'fail').lower() == 'ok':
            print 'Init node %s success'%(newnode)
        elif 'error' in ret:
            print 'Error: %s'%(ret['error'])
        else:
            print 'Unknow Error'
        # update node acl and data
        #node_data = dict(ip=ip, port=port)
        #ret = roshan.update_node(newnode, acl=acls, data=json.dumps(node_data))
        #if 'error' in ret:
        #    print 'Error: %s'%(ret['error'])
        #elif 'status' in ret:
        #    print 'Update node %s: %s'%(newnode, ret['status'])
    return 0


def display_tree(path, level=1):
    roshan = Roshan(*config['addr'])
    if 'incorrect' in roshan.login(*config['account']):
        print 'Wrong Username/Email and password combination.'
        return -1
    nodes = roshan.get_node_list(path)
    if not nodes :
        print 'Node path "%s" error or node is empty' % path
        return -1
    if 'error' in nodes:
        print 'GetNodeError: %s'%(nodes['error'])
        return -1

    if level == 1:
	    print ( "%s/" % path)
    for node in nodes:
        _print_prefix(level)
        if node['leaf']:
            print os.path.basename(node['id'])
        else:
            print os.path.basename(node['id'])
            display_tree(node['id'], level+1)
    return 0 


def show(path):
    roshan = Roshan(*config['addr'])
    if 'incorrect' in roshan.login(*config['account']):
        print 'Wrong Username/Email and password combination.'
        return -1
    node = roshan.get_node(path)
    if 'error' in node:
        print node['error']
        return -1
    node_acls = node['acl']
    print 'Path:\n\t%s'%(path)
    print 'Acls:'
    for node_acl in node_acls:
        print '\t%s\t%s\t%d\t%s'%(
            node_acl['scheme'].rjust(7),
            node_acl['acl_id'].ljust(16),
            node_acl['perms'],
            node_acl['host'].rjust(32))
    node_data = node['data']
    node_stat = node['stat']
    print 'Data:\n\t%s'%(node_data)
    if 'error' in node_stat:
        print 'Stat:\n\t%s'%node_stat['error']
    else:
        print 'Stat:\n\t%s'%('\n\t'.join(
            ["%s: %s"%(s['name'].ljust(16), s['value']) for s in node_stat]))


def delete(path, key):
    roshan = Roshan(*config['addr'])
    if 'incorrect' in roshan.login(*config['account']):
        print 'Wrong Username/Email and password combination.'
        return -1
    nodes = roshan.get_node_list(path)
    if not nodes:
        print 'Node path "%s" error or node is empty' % path
        return -1
    if 'error' in nodes:
        print 'GetNodeError: %s'%(nodes['error'])
        return -1
    for node in nodes:
        if key in node['text']:
            ret = roshan.delete_node(node['id'])
            if not ret:
                print "Failed to delete node %s"(node['id'])
                continue
            if 'error' in ret:
                print "Delete %s Error: %s"%(node['id'], ret['error'])
                continue
            if ret.get('status', '') == 'ok':
                print "Delete %s success"%(node['id'])


def main():
    func_map = {
        'load': load,
        'list': display_tree,
        'show': show,
        'delete': delete,
    }
    try:
        func = func_map.get(sys.argv[1], None)
        if func is not None:
            try:
                return func(*sys.argv[2:])
            except TypeError, errmsg:
                print 'CallFunctionError %s: %s'%(sys.argv[1], errmsg)
    except IndexError:
        pass
    print __usage__ %(dict(argv0=sys.argv[0]))
    

if __name__ == '__main__':
    sys.exit(main())
