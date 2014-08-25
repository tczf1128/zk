all:server client

server:server.c
	gcc -g  -o server server.c -L ./mylib/lib -lzookeeper_mt -lpthread


client:client.c
	gcc -g  -o client client.c -L ./mylib/lib -lzookeeper_mt -lpthread


clean:
	rm server client

