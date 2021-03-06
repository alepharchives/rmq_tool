-module(rmq_tool).

-include_lib("amqp_client/include/amqp_client.hrl").
-include("logging.hrl").


-export([
	% aliases from dump
	dump/3,
	dump/2,
	dump/1,

	% aliases from inject
	inject/2,
	inject/3,
	inject/4,

	purge/1,
	delete_queue/1,
	list_dumps/0,
	help/0
]).

%% ===================================================================
%% APIs
%% ===================================================================

delete_queue(QueueName) when is_binary(QueueName) ->
	Channel = rmq_connection:get_channel(),
	try
		Delete = #'queue.delete'{queue = QueueName},
		#'queue.delete_ok'{} = amqp_channel:call(Channel, Delete),
		?log_info("Successfully deleted", [])
	catch
		Class:Error -> ?log_error("Delete error ~p:~p", [Class,Error])
	end.


%% @doc Purges queue
-spec purge(QueueName :: binary()) -> ok.
purge(QueueName) ->
	Channel = rmq_connection:get_channel(),
	?log_info("Purging the queue ~p...  ", [QueueName]),
	try
		Purge = #'queue.purge'{queue = QueueName},
		{'queue.purge_ok', Count} = amqp_channel:call(Channel, Purge),
		?log_info("~p message(s) purged", [Count])
	catch
		_Ex:Reason -> ?log_error("Purging error: ~p.", [Reason])
	end,
 	ok.


%% @doc dump queue
-spec dump(QueueName :: binary()) -> ok.
dump(QueueName) ->
	rmq_dump:dump(QueueName).


%% @doc dump queue, limiting amount of dumped messages
-spec dump(QueueName :: binary(), MaxMessages :: integer()) -> ok.
dump(QueueName, Max) ->
	rmq_dump:dump(QueueName, Max).


%% @doc dump queue, limiting amount of dumped messages
-spec dump(QueueName :: binary(), MaxMessages :: integer(), NoAck :: atom()) -> ok.
dump(QueueName, Max, NoAck) ->
	rmq_dump:dump(QueueName, Max, NoAck).


%% @doc injecting queue with all data taken from a file
-spec inject(QueueName :: binary(), FileName :: string()) -> ok.
inject(QueueName, DumpNumber) when is_integer(DumpNumber) ->
	{ok, Dumps} = get_dump_list(),
	FileName = lists:nth(DumpNumber, Dumps),
	inject(QueueName, FileName);
inject(QueueName, FileName) ->
	rmq_inject:inject(QueueName, FileName).


%% @doc injecting queue with all data taken from a file. Skipping a couple of starting messages
-spec inject(QueueName :: binary(), FileName :: string(), Offset :: integer()) -> ok.
inject(QueueName, DumpNumber, Offset) when is_integer(DumpNumber) ->
	{ok, Dumps} = get_dump_list(),
	FileName = lists:nth(DumpNumber, Dumps),
	inject(QueueName, FileName, Offset);
inject(QueueName, FileName, Offset) ->
	rmq_inject:inject(QueueName, FileName, Offset).


%% @doc injecting queue with all data taken from a file. Skipping a couple of starting messages and limits amount
-spec inject(QueueName :: binary(), FileName :: string(), Offset :: integer(), Count :: integer()) -> ok.
inject(QueueName, FileName, Offset, Count) ->
	rmq_inject:inject(QueueName, FileName, Offset, Count).

%% @doc List all available dump files
-spec list_dumps() -> ok.
list_dumps() ->
	{ok, Dumps} = get_dump_list(),
	Print = fun(N) ->
		Name = lists:nth(N, Dumps),
		io:format("~p: ~p~n", [N, Name])
	end,
	lists:foreach(Print, lists:seq(1, length(Dumps))).

get_dump_list() ->
	RawList = os:cmd("ls ./dumps"),
	ListOfDumps = string:tokens(RawList, "\n"),
	{ok, ListOfDumps}.

%% @doc Print help info
-spec help() -> ok.
help() ->
	Messages = [
	"Purge queue: ~n"
	"rmq_tool:purge(<<\"pmm.mmwl.response.sms\">>).~n",
	"Dupm all messages in queue: ~n"
	"rmq_tool:dump(<<\"pmm.mmwl.response.sms\">>).~n",
	"Dump 1000 messages in queue: ~n"
	"rmq_tool:dump(<<\"pmm.mmwl.response.sms\">>, 1000).~n",
	"List available dumps: ~n"
	"rmq_tool:list_dumps().~n",
	"Inject all messages into queue: ~n"
	"rmq_tool:inject(<<\"pmm.mmwl.response.sms\">>, 1)~n"
	"rmq_tool:inject(<<\"pmm.mmwl.response.sms\">>, \"pmm.mmwl.response.sms_20121022_17184.qdump\")~n",
	"Advanced inject messages into queue: ~n"
	"rmq_tool:inject(QueueName, FileName, Offset, Count)~n",
	"Delete queue: ~n"
	"rmq_tool:delete_queue(<<\"queue_name\">>).~n"
	],
	lists:foreach(fun(S) ->
		io:format(S ++ "~n", [])
	end, Messages),
	ok.
