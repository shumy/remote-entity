package rt.vertx.server

import io.vertx.core.eventbus.EventBus
import io.vertx.core.eventbus.MessageConsumer
import rt.pipeline.IMessageBus
import org.eclipse.xtend.lib.annotations.Accessors
import rt.pipeline.IMessageBus.Message

class VertxMessageBus implements IMessageBus {
	@Accessors String defaultAddress
	val converter = new MessageConverter
	
	val EventBus eb
	
	new(EventBus eb) {
		this.eb = eb
	}
	
	override publish(Message msg) {
		publish(defaultAddress, msg)
	}
	
	override publish(String address, Message msg) {
		val textMsg = converter.toJson(msg)
		
		println('''PUBLISH(«address») «textMsg»''')
		eb.publish(address, textMsg)
	}
	
	override listener(String address, (Message) => void listener) {
		val consumer = eb.consumer(address) [
			val msg = converter.fromJson(body as String)
			listener.apply(msg)
		]

		return new VertxListener(consumer)
	}
	
	static class VertxListener implements IListener {
		val MessageConsumer<Object> consumer
		
		new(MessageConsumer<Object> consumer) {
			this.consumer = consumer
		}
		
		override remove() {
			consumer.unregister
		}
	}
}