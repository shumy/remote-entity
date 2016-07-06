package rt.ws.client

import java.net.URI
import java.nio.ByteBuffer
import org.eclipse.xtend.lib.annotations.Accessors
import org.java_websocket.client.WebSocketClient
import org.java_websocket.handshake.ServerHandshake
import org.slf4j.LoggerFactory
import rt.pipeline.pipe.PipeResource
import rt.pipeline.pipe.channel.ChannelPump
import rt.pipeline.pipe.channel.IChannelBuffer
import rt.pipeline.pipe.channel.IPipeChannel
import rt.pipeline.pipe.channel.ReceiveBuffer
import rt.pipeline.pipe.channel.SendBuffer

import static rt.pipeline.pipe.channel.IPipeChannel.PipeChannelInfo.Type.*

class ClientPipeChannel implements IPipeChannel {
	static val logger = LoggerFactory.getLogger('CLIENT-CHANNEL')
	
	@Accessors val PipeResource resource
	@Accessors val PipeChannelInfo info
	@Accessors(PUBLIC_GETTER) var IChannelBuffer buffer
	@Accessors val String status
	
	val URI url
	val ChannelPump inPump
	
	WebSocketClient ws = null
	
	package new(PipeResource resource, PipeChannelInfo info, String client) {
		this.resource = resource
		this.info = info
		this.status = 'INIT'
		
		this.url = new URI(resource.client + '?client=' + client + '&channel=' + info.uuid)
		
		inPump = new ChannelPump
		val outPump = new ChannelPump => [
			onSignal = [ ws.send(it) ]
			onData = [
				//TODO: buffer array can be aout of limit!
				ws.send(array)
			]
		]
		
		this.buffer = if (info.type == SENDER) new SendBuffer(outPump, inPump) else new ReceiveBuffer(inPump, outPump)
	}
	
	override close() { ws?.close }
	
	def connect() {
		logger.info('TRY-OPEN {}', url)
		ws = new WebSocketClient(url) {
			
			override onOpen(ServerHandshake handshakedata) {
				logger.trace('OPEN {}', info.uuid)
			}
			
			override onClose(int code, String reason, boolean remote) {
				logger.trace('CLOSE {}', info.uuid)
				resource.removeChannel(info.uuid)
				buffer.close
			}
			
			override onError(Exception ex) {
				ex.printStackTrace
			}
			
			override onMessage(String signal) {
				inPump.pushSignal(signal)
			}
			
			override onMessage(ByteBuffer byteMsg) {
				inPump.pushData(byteMsg)
			}
		}
		
		ws.connectBlocking
	}
}