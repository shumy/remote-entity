package rt.pipeline

import java.util.HashMap
import java.util.Set
import java.util.HashSet
import rt.pipeline.IMessageBus.Message
import java.util.Timer
import java.util.concurrent.ConcurrentHashMap

class DefaultMessageBus implements IMessageBus {
	val listeners = new HashMap<String, Set<DefaultListener>>
	val replyListeners = new ConcurrentHashMap<String, (Message) => void>
	
	
	override publish(String address, Message msg) {
		if (msg.typ != null) msg.typ = Message.PUBLISH
		listeners.get(address)?.forEach[ send(msg) ]
	}
	
	override send(String address, Message msg, (Message) => void replyCallback) {
		val replyID = '''«msg.clt»+«msg.id»'''
		replyListeners.put(replyID, replyCallback)
		
		msg.typ = Message.SEND
		listeners.get(address)?.forEach[ send(msg) ]
		
		new Timer().schedule([
			val replyFun = replyListeners.remove(replyID)
			replyFun?.apply(new Message => [ id=msg.id clt=msg.clt typ=Message.REPLY cmd=Message.CMD_ERROR result='''Timeout for «msg.path» -> «msg.cmd»'''.toString])
		], 3000)
	}
	
	override reply(Message msg) {
		val replyID = '''«msg.clt»+«msg.id»'''
		val replyFun = replyListeners.remove(replyID)
		replyFun?.apply(msg)
	}
	
	override listener(String address, (Message) => void listener) {
		var holder = listeners.get(address)
		if (holder == null) {
			holder = new HashSet
			listeners.put(address, holder)
		}
		
		val rtsListener = new DefaultListener(this, address, listener)
		holder.add(rtsListener)
		
		return rtsListener
	}
	
	static class DefaultListener implements IListener {
		val DefaultMessageBus parent
		val String address
		val (Message) => void  callback
		
		package new(DefaultMessageBus parent, String address, (Message) => void callback) {
			this.parent = parent
			this.address = address
			this.callback = callback
		}
		
		def send(Message msg) {
			callback.apply(msg)
		}
		
		override remove() {
			val holder = parent.listeners.get(address)
			holder?.remove(this)
		}
	}
}