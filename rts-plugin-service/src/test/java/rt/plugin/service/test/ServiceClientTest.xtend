package rt.plugin.service.test

import java.util.Collections
import org.junit.Test
import rt.async.AsyncUtils
import rt.pipeline.bus.DefaultMessageBus
import rt.pipeline.bus.Message
import rt.plugin.service.ServiceClient

class ServiceClientTest {
	
	@Test
	def void verifyCall() {
		AsyncUtils.setDefault
		
		val mb = new DefaultMessageBus
		mb.subscribe('clt:address')[ msg |
			val reply = switch msg.cmd {
				case 'hello': new Message => [id=msg.id clt=msg.clt cmd='ok']
				case 'sum':   new Message => [id=msg.id clt=msg.clt cmd='ok' result=13.4]
				case 'error': new Message => [id=msg.id clt=msg.clt cmd='error' result='Error message!']
			}
			
			mb.publish(reply.clt + '+' + reply.id, reply)
		]
		
		val srvClient = new ServiceClient(null, mb, 'srv:address', 'clt:address', Collections.EMPTY_MAP)
		val srvProxy = srvClient.create('test', SrvInterface)
		
		srvProxy.hello('Alex').then[
			println('REPLY-OK')
		]

		srvProxy.sum(2, 3L, 3.4f, 5.0).then[
			println('REPLY-OK: ' + it)
		]
		
		srvProxy.error
			.then([ println('REPLY-OK!') ], [ println('REPLY-ERROR: ' + it) ])
	}
}