#!/usr/bin/env python

import os
import re
import sys
import json
from roshan import Roshan
from conf import *
import traceback


__usage__ = """Add node or update acl in zk.

Example

%(argv0)s add_node site_list
The site_list looks like
    #domain_name full_path
    topcar09.baidu.com /sandbox/ns/cms/other/topcar09

Or %(argv0)s update_acl conffile
    The conffile looks like
    [server]
    xxx.xxx.xxx.xxx
    xxx.xxx.xxx.xxx
    [path]
    /baidu/ns/cms/path/to/node
"""

_version_ = "0.0.0.3"

roshan=None

default_acls=['ip:127.0.0.1:7','ip:10.65.33.135:7','ip:10.65.33.235:7','ip:10.81.33.37:7']

def login():
    global roshan
    roshan = Roshan(*config['addr'])
    if 'incorrect' in roshan.login(*config['account']):
        print 'Wrong Username/Email and password combination.'
        return -1

def add_abslute_path(path):
    """
        actually add a node
    """
    ret = roshan.add_node(path)
    if ret.get('status','fail').lower() == 'ok':
        print 'Create node %s success' % path
    elif 'error' in ret:
        print 'Error: %s' % ret['error']
    else:
        print 'Unknown error'
    
def add_one_site(domain, rootpath="/sandbox/cms-op"):
    """
        add a single site node and update the data
    """
    head=''
    nodes = rootpath.split('/')
    for n in nodes:
        if n:
            head = head + '/' + n
            add_abslute_path(head)
    path=head
    add_abslute_path(path)
    data=make_node_data(domain)
    ret = roshan.update_node(path,generate_acl(),json.dumps(data),isappend=False)
    if 'error' in ret:
        print 'Error: %s'%(ret['error'])
    elif 'status' in ret:
        print 'create %s: %s' %( path, ret['status'])

def make_node_data(domain, port=1110, cmspm_num=1):
    """
        make the data of a node
    """
    data={}
    data['check_cmspm_num']=1
    data['cmspm_num']=cmspm_num
    data['is_work']=1
    data['service_conn_type']=0
    data['service_name']=domain
    data['service_port']=port
    data['service_type']=0
    serv={}
    serv[domain]=data
    node={}
    node['name']="cms"
    node['services']=serv
    return node


def read_conf(file):
    """
     load domains and path from a file
    """

    f=open(file)
    domain_path={}
    while True:
        line = f.readline().strip()
        if len(line) == 0:
            break
        if line.startswith('#'):
            continue
        domain,path = line.split()
        domain_path[domain]=path
    return domain_path


def check_user():
	if config['account'][0] == 'cms':
		#ok
		return 1
	else:
		return 0

#add_node node_conf
#the format of node_conf
#xxx.baidu.com /baidu/ns/cms/xxxx/xxxxxx
def add_node(node_conf):
	##main program
	if not check_user():
		print "only user cms can add a new node."
		return 0
	login()
	#add_one_site('test_domain','/sandbox/a/b/c/d')            
	datafile=node_conf
	if datafile :
		domain_path=read_conf(datafile)
		for key in domain_path.keys():
		    add_one_site(key,domain_path[key])
	else:
		print """
add_node node_conf
the format of node_conf_file should be
xxx.baidu.com /baidu/ns/cms/xxxx/xxxx
"""

def get_node_data(path):
        node = roshan.get_node(path)
        if not node:
                print "error in get node %s, error: %s" %(path, node)
                return None,None,None
        node_acls = node.get('acl')
        node_data = node.get('data')
        stat_arr = node.get('stat')
        if node_data is not None and len(node_data) != 0:
                if node_data[-1] == '\0' :
                        node_data = node_data.rstrip('\0')
                node_dict = json.loads(node_data)
        else:
                node_dict = None
        return node_dict


def update_node_dict(node_dict, cmspm_num=1):
	serv=node_dict['services']
	name = node_dict['name']
	domain = str(serv.keys()[0])
	domain_data = serv[domain]
	port = domain_data['service_port']
	return make_node_data(domain, port=port, cmspm_num=cmspm_num)

import re
def parse_acl_conf(acl_conf):
	acl_file = file(acl_conf)
	acl_lines = acl_file.readlines()
	acl_dict = {}
	key = None
	for line in acl_lines:
		#if match [xxx], add a key
		#else add the string to last key
		
		p=re.compile('\\[.*]',re.IGNORECASE)
		line = line.rstrip()
		if len(line) == 0:
			continue
		m=p.match(line)
		if m is None:
		#add to a certern array
			if key :
				acl_dict[key].append(line)
		else:
			last_key = key
			key = str(m.group())[1:-1]
			acl_dict[key]=[]
		
		
	path =acl_dict['path'][0]
	acl_list = acl_dict['server']
	return path,acl_list



def generate_acl(acl_list=""):
	acl = ""
	for i in acl_list:
		acl = acl+('ip:%s:7\n' % i)
	for i in default_acls:
		acl = acl +('%s\n' % i)
	return acl

#update_acl acl_conf
#should replace the acls of the node and set "cmspm_num"
#
def update_acl(acl_file):
	login()
#first get data and parse it
	path,acl_list = parse_acl_conf(acl_file)
	acl_count = len(acl_list)
	node_dict = get_node_data(path)
#second, replace the acl and the data
	node_dict = update_node_dict(node_dict,cmspm_num=acl_count)
	print 'cmspm_num: '+ str(acl_count)+ ' newdata: '+str(node_dict)
	acl = generate_acl(acl_list)
	print 'acl: '+ str(acl)
	roshan.update_node(path,data=json.dumps(node_dict),acl=acl,isappend=False)


def main():
    func_map = {
        'add_node': add_node,
        'update_acl': update_acl,
    }
    try:
        func = func_map.get(sys.argv[1], None)
        if func:
            try:
                return func(*sys.argv[2:])
            except TypeError,errmsg:
                print 'CallFunctionError %s: %s'%(sys.argv[1], errmsg)
    except IndexError:
        pass
    print __usage__ % (dict(argv0=sys.argv[0]))

if __name__ == '__main__':
	exit(main())
