#include <string.h>
#include <stdio.h>
#include <errno.h>
#include <unistd.h>
#include "c_client/include/zookeeper.h"

//static zhandle_t *zh;
void watcher(zhandle_t *zh,int type,int state,const char *path,void *watcherCtx){}

int main(int argc,char *argv[])
{
    char buffer[512];

    const char *host = "10.46.46.54:2181,10.48.50.42:2182,10.46.190.15:2181";

    zhandle_t *zh = zookeeper_init(host,watcher,30000,0,0,0);
    if(zh == NULL)
    {
        fprintf(stderr,"Error when connecting to zookeeper servers...\n");
        exit(EXIT_FAILURE);
    }

    int ret = zoo_create(zh,"/groups/master2","10.48.50.42",11,&ZOO_OPEN_ACL_UNSAFE, ZOO_EPHEMERAL|ZOO_SEQUENCE,buffer,sizeof(buffer)-1);
    if(ret)
    {
        fprintf(stderr,"Error %d for create\n",ret);
        exit(EXIT_FAILURE);
    }

    // server context
    while(1)
    {
        sleep(10000);
    }

    zookeeper_close(zh);
}
