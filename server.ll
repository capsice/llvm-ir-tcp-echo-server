target triple = "x86_64-pc-linux-gnu"

%struct.sockaddr_in = type { 
  i16,              ; sin_family
  i16,              ; sin_port
  %struct.in_addr,  ; sin_addr 
  [8 x i8]          ; sin_zero
}

%struct.in_addr = type { 
  i32 ; s_addr 
}

%struct.sockaddr = type { 
  i16, ; sa_family
  [14 x i8] ; sa_data
}

@.error = private unnamed_addr constant [24 x i8] c"there has been an error\00", align 1
@.listening = private unnamed_addr constant [22 x i8] c"listening on port %d\0A\00", align 1


define void @echo(i32 %client) #0 {
  ; Allocate our buffer and cast it to an i8*
  %buffer = alloca [4096 x i8]
  %buffer_ptr = bitcast [4096 x i8] *%buffer to i8*
  br label %echo_loop
  
echo_loop:
  ; Echo loop
  ; Here we read and write until either one of the calls returns <= 0
  %read_count = call i64 @read(i32 %client, i8 *%buffer_ptr, i64 4096)
  ; Handle errors
  %err_read = icmp sle i64 %read_count, 0
  br i1 %err_read, label %end, label %write

write:

  %write_count = call i64 @write(i32 %client, i8 *%buffer_ptr, i64 %read_count)
  ; Handle errors
  %err_write = icmp sle i64 %write_count, 0
  br i1 %err_write, label %end, label %echo_loop
  ; End echo loop

end:

  call i32 @close(i32 %client)
  ret void
}

define i32 @main(i32 %argc, i8 **%argv) {
  ; Init our return code and set it to 0
  %rc = alloca i32, align 4
  store i32 0, i32 *%rc, align 4

  ; Set up our port variable
  %port_ptr = alloca i16, align 2
  store i16 8080, i16 *%port_ptr, align 2

  %has_port_argv = icmp sgt i32 %argc, 1
  br i1 %has_port_argv, label %parse_port, label %setup_address

parse_port:

  %argv2_ptr = getelementptr inbounds i8*, i8 **%argv, i32 1
  %argv2 = load i8*, i8 **%argv2_ptr, align 8
  ; Parse our port
  %port_unchecked = call i64 @strtol(i8 * %argv2, i8 **null, i32 10)
  ; Check if our port is out of bounds
  %is_port_too_big = icmp sgt i64 %port_unchecked, 65535
  %is_port_too_small = icmp slt i64 %port_unchecked, 1
  %is_port_out_of_bounds = or i1 %is_port_too_big, %is_port_too_small
  br i1 %is_port_out_of_bounds, label %err, label %save_port

save_port:
  ; Update the value of our port in memory
  %porti16 = trunc i64 %port_unchecked to i16
  store i16 %porti16, i16 *%port_ptr, align 2
  br label %setup_address

setup_address:
  ; Here we prepare our sockaddr_in struct
  %address = alloca %struct.sockaddr_in, align 4
  ; Fill address.sin_addr.s_addr
  %address.sin_addr = getelementptr inbounds %struct.sockaddr_in, %struct.sockaddr_in *%address, i32 0, i32 2
  %address.sin_addr.s_addr = getelementptr inbounds %struct.in_addr, %struct.in_addr *%address.sin_addr, i32 0, i32 0
  store i32 0, i32 *%address.sin_addr.s_addr, align 4 ; INADDR_ANY
  ; Fill address.sin_port
  %port = load i16, i16 *%port_ptr, align 2
  %ns_port = call i16 @htons(i16 %port)
  %address.sin_port = getelementptr inbounds %struct.sockaddr_in, %struct.sockaddr_in *%address, i32 0, i32 1
  store i16 %ns_port, i16 *%address.sin_port, align 2
  ; Fill address.sin_family
  %address.sin_family = getelementptr inbounds %struct.sockaddr_in, %struct.sockaddr_in *%address, i32 0, i32 0
  store i16 2, i16 *%address.sin_family, align 4 ; AF_INET
  
  br label %setup_socket

setup_socket:
  ; Socket setup
  ; Here we create, bind and listen

  ; Create
  %fd = call i32 @socket(
    i32 2, ; AF_INET
    i32 1, ; SOCK_STREAM
    i32 0
  )

  %err_fd = icmp eq i32 %fd, -1
  br i1 %err_fd, label %err, label %bind

bind:
  ; Bind
  ; We cast our sockaddr_in* to sockaddr* much like in C
  %casted_addr = bitcast %struct.sockaddr_in *%address to %struct.sockaddr*
  ; The size of struct sockaddr_in is 16, hence the last argument
  %bind_rc = call i32 @bind(i32 %fd, %struct.sockaddr *%casted_addr, i32 16)
  ; Handle errors
  %err_bind = icmp eq i32 %bind_rc, -1
  br i1 %err_bind, label %err, label %listen

listen:
  ; Listen
  %listen_rc = call i32 @listen(i32 %fd, i32 16)
  ; Handle errors
  %err_listen = icmp eq i32 %listen_rc, -1
  br i1 %err_listen, label %err, label %accept_loop
  ; End socket setup

accept_loop:

  %listening = bitcast [22 x i8] *@.listening to i8*
  call i32 (i8*, ...) @printf(i8 *%listening, i16 %port)
  ; Accept loop
  ; Here we accept connections forever and forward them to the echo loop
  %client = call i32 @accept(i32 %fd, %struct.sockaddr *null, i64 *null)
  ; Handle errors
  %err_accept = icmp eq i32 %client, -1
  ; If accept fails for whatever reason, we simply loop back
  br i1 %err_accept, label %accept_loop, label %echo

echo:

  call void @echo(i32 %client)
  br label %accept_loop
  ; End accept loop

err:

  %error = bitcast [24 x i8] *@.error to i8*
  call i32 @puts(i8 *%error)
  ; Set our return code to 1
  store i32 1, i32 *%rc, align 4
  br label %end

end:

  %exit_code = load i32, i32 *%rc, align 4
  ret i32 %exit_code
}

declare i16 @htons(i16) nounwind
declare i32 @socket(i32, i32, i32) nounwind
declare i32 @close(i32) nounwind
declare i32 @bind(i32, %struct.sockaddr*, i32) nounwind
declare i32 @listen(i32, i32) nounwind
declare i32 @accept(i32, %struct.sockaddr*, i64*) nounwind
declare i64 @read(i32, i8*, i64) nounwind
declare i64 @write(i32, i8*, i64) nounwind
declare i32 @puts(i8*) nounwind
declare i32 @printf(i8*, ...) nounwind
declare i64 @strtol(i8*, i8**, i32) nounwind
