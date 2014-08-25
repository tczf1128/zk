#include <string.h>
#include <stdio.h>
#include <errno.h>
#include <unistd.h>
#include "c_client/include/zookeeper.h"

//static zhandle_t *zh;

void update_server_list(zhandle_t *zh)
{
    // update server list
    int i;
    struct String_vector paths;
    int ret = zoo_get_children(zh,"/groups",1,&paths);// note: free mem
    if(ret)
    {
        fprintf(stderr,"Error %d for get_children\n",ret);
        exit(EXIT_FAILURE);
    }
    for(i = 0;i < paths.count;i++)
        printf("/groups/%s\n",paths.data[i]);

    putchar('\n');
}
void watcher(zhandle_t *zh,int type,int state,const char *path,void *watcherCtx)
{
    int status = 0;

    if(type == ZOO_CHILD_EVENT && strcmp(path,"/groups") == 0)
    {
        update_server_list(zh);
        status = 1;
    }
    if (!status)
        update_server_list(zh);
}

int main(int argc,char *argv[])
{
    const char *host = "10.46.46.54:2181,10.48.50.42:2182,10.46.190.15:2181";

    zhandle_t *zh = zookeeper_init(host,watcher,30000,0,0,0);
    if(zh == NULL)
    {
        fprintf(stderr,"Error when connecting to zookeeper servers...\n");
        exit(EXIT_FAILURE);
    }

    // client context
    while(1)
    {
        sleep(10000);
    }

    zookeeper_close(zh);
}
