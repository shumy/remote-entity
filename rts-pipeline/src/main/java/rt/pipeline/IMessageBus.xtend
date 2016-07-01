package rt.pipeline

import java.util.List

interface IMessageBus {
	
	def void publish(String address, Message msg)
	
	def void send(String address, Message msg, (Message) => void replyCallback)
	
	def IListener listener(String address, (Message) => void listener)
	
	public interface IListener {
		def void remove()
	}
	
	public static class Message {
		public static val String OK = 'ok'
		public static val String ERROR = 'error'
		
		// from all
		public Long id
		public String cmd
		public String clt
		public String path
		
		// from request
		transient List<String> jsonArgs
		transient (List<String>, Class<?>[]) => List<Object> argsConverter = null
		List<Object> args = null
		
		// from response
		transient String jsonResult
		transient (String, Class<?>) => Object resultConverter = null
		Object res = null
		
		public String error
		
		new() {}
		new(List<String> jsonArgs, (List<String>, Class<?>[]) => List<Object> argsConverter, String jsonResult, (String, Class<?>) => Object resultConverter) {
			this.jsonArgs = jsonArgs
			this.argsConverter = argsConverter
			this.jsonResult = jsonResult
			this.resultConverter = resultConverter
		}
		
		def void setArgs(List<Object> args) { this.args = args }
		def List<Object> args(Class<?> ...types) {
			if (args == null)
				args = argsConverter?.apply(jsonArgs, types)
			return args
		}
		
		def void setResult(Object value) { this.res = value }
		def <T> T result(Class<T> type) {
			if (res == null)
				res = resultConverter?.apply(jsonResult, type)
			return res as T
		}
	}
}