import ballerina/http;

service / on new http:Listener(8090) {
    resource function post .(@http:Payload string textMsg) returns string {
        return textMsg;
    }

    resource function post echo/hello (@http:Payload string textMsg) returns string {
        return "Hello" + textMsg;
    }
}
