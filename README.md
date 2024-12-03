# Godot-Nexus (WIP)
A minimal Godot extension and SDK to manage online game sessions in godot.

- **Nexus** The transport layer, a lighweight network protocol implemented for Websocket and TCP
- **NetRoot** The Scene syncronizer, register entities and sincronize them over the network
- **NetEntities** Entities are nodes that synconize,send anr recieve messages over the network
.
Websocket transport must be used in conjunction with project [gonexus] (https://github.com/krshock/gonexus)(A Golang Websocket Server) to provide play room sessions to share with friends on the internet

## This extension is a Work In Progress
