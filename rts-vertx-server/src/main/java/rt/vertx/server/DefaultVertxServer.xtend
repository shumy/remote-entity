package rt.vertx.server

import io.vertx.core.Vertx
import io.vertx.core.http.HttpServer
import io.vertx.core.http.HttpServerOptions
import org.eclipse.xtend.lib.annotations.Accessors
import rt.async.AsyncUtils
import rt.pipeline.bus.ContextUtils
import rt.pipeline.bus.DefaultMessageConverter
import rt.pipeline.bus.IMessageBus
import rt.pipeline.pipe.Pipeline
import rt.vertx.server.web.WebRouter
import rt.vertx.server.ws.WsRouter

import static rt.pipeline.bus.ContextUtils.*

class DefaultVertxServer {
	@Accessors val HttpServer server
	@Accessors val Pipeline pipeline
	@Accessors val WsRouter wsRouter
	@Accessors val WebRouter webRouter
	
	@Accessors val converter = new DefaultMessageConverter
	
	def IMessageBus getMb() { return pipeline.mb }
	
	package val Vertx vertx
	
	new(Vertx vertx, String wsBaseRoute, String webBaseRoute) {
		this.vertx = vertx
		
		this.server = vertx.createHttpServer(new HttpServerOptions => [
			tcpKeepAlive = true
			maxWebsocketFrameSize = 1048576
		])
		
		this.pipeline = new Pipeline
		this.wsRouter = new WsRouter(this, wsBaseRoute)
		this.webRouter = new WebRouter(this, webBaseRoute)
		
		AsyncUtils.set(new VertxAsyncUtils(vertx))
		ContextUtils.publisher = pipeline.mb
	}
	
	def void listen(int port) {
		server.listen(port)
	}
}