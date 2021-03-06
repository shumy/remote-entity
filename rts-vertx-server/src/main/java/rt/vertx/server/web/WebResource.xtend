package rt.vertx.server.web

import io.netty.buffer.Unpooled
import io.vertx.core.buffer.Buffer
import io.vertx.core.http.HttpServerRequest
import io.vertx.core.http.HttpServerResponse
import java.nio.ByteBuffer
import java.util.HashMap
import java.util.List
import java.util.Map
import org.eclipse.xtend.lib.annotations.Accessors
import org.slf4j.LoggerFactory
import rt.pipeline.bus.Message
import rt.pipeline.pipe.PipeResource
import rt.plugin.service.CtxHeaders
import rt.plugin.service.RouteConfig
import rt.plugin.service.ServiceException

class WebResource {
	static val logger = LoggerFactory.getLogger('WEB-RESOURCE')
	
	val mimeTypes = #{
		'json'	-> 'application/json',
		'css'	-> 'text/css'
	}
	
	@Accessors val String client
	
	val WebRouter parent
	val RouteConfig config
	
	package new(WebRouter parent, RouteConfig config) {
		this.parent = parent
		this.client = config.requestPath
		this.config = config
	}
	
	def void process(HttpServerRequest req, List<String> routeSplits, Map<String, String> queryParams) {
		//if is REST service, add route parameters
		val routeParams = config.getParameters(routeSplits)
		val simplePath = req.path.replaceAll('//', '/')
		
		/*println('REQUEST -> ' + routeSplits)
		queryParams.keySet.forEach[ key |
			print('''  «key»:«queryParams.get(key)» ''')
		]*/
		
		//create msg parameters
		val params = new HashMap<String, Object> => [
			putAll(queryParams)
			putAll(routeParams)
		]
		
		//TODO: search for reserved params?
		
		//create resource and process message
		val resource = parent.pipeline.createResource(client) => [
			sendCallback = [
				logger.trace('RESPONSE {} {}', cmd, client)
				processResponse(req.response, simplePath)
			]
			
			contextCallback = [
				val headers = new CtxHeaders
				parent.headersProcessor?.apply(req.headers, headers)
				object(CtxHeaders, headers)
			]
		]
		
		logger.trace('REQUEST {}', client)
		
		params.put('ctx.path', '''"«simplePath»"'''.toString)
		if (!config.processBody) {
			params.put('ctx.request', req)
			
			//direct mode, request body will be processed in the service
			resource.processRequest(params)
		} else {
			//not a direct process, translate body
			req.bodyHandler[
				val textBody = getString(0, length)
				params.put('body', textBody)
				
				resource.processRequest(params)
			]
		}
	}
	
	private def void processRequest(PipeResource resource, Map<String, Object> params) {
		val rawParams = config.paramMaps.map[ params.get(it) ]
		val argsConverter = parent.converter.createArgsConverter(rawParams)
		
		val msg = new Message(argsConverter, null) => [
			id = 0L
			typ = Message.SEND
			path = 'srv:' + config.srvAddress
			cmd = config.srvMethod
		]
		
		resource.process(msg)
	}
	
	private def void processResponse(Message reply, HttpServerResponse res, String path) {
		if (reply.cmd != Message.CMD_OK) {
			//process exception...
			val ex = reply.result(RuntimeException)
			if (ex instanceof ServiceException) {
				val sex = ex as ServiceException
				res.statusCode = sex.httpCode
				res.end(sex.message)
			} else {
				res.statusCode = 500
				res.end(ex.message)
			}
			
			logger.error('Request error: {} {}', res.statusCode, ex.message)
			return
		}
		
		//process result...
		res.statusCode = 200
		val result = reply.result(Object)
		if (result == null) {
			res.end
		} else if (result.class == String) {
			res.putHeader('Content-Type', 'text/plain')
			res.end(result as String)
		} else if (result instanceof ByteBuffer) {
			val cntBuffer = result as ByteBuffer
			val buffer = Buffer.buffer(Unpooled.wrappedBuffer(cntBuffer))
			
			val splits = path.split('\\.')
			val mimeType = if (splits.length > 1)
				mimeTypes.get(splits.get(splits.length - 1))
			
			if (mimeType != null)
				res.putHeader('Content-Type', mimeType)
			
			res.end(buffer)
		} else {
			res.putHeader('Content-Type', 'application/json')
			res.end(parent.converter.toJson(result))
		}
	}
}