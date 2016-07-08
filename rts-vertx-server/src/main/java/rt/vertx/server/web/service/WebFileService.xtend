package rt.vertx.server.web.service

import io.vertx.core.http.HttpServerRequest
import org.slf4j.LoggerFactory
import rt.pipeline.PathValidator
import rt.plugin.service.an.Public
import rt.plugin.service.an.Service

@Service
class WebFileService {
	static val logger = LoggerFactory.getLogger('HTTP-FILE-REQUEST')
	
	val String folder
	
	new(String folder) {
		this.folder = folder
	}
	
	@Public(notif = true)
	def void get(HttpServerRequest req) {
		//protect against filesystem attacks
		if (!PathValidator.isValid(req.path)) {
			logger.error('Request path not accepted: {}', req.path)
			
			req.response.statusCode = 403
			req.response.end = 'Request path not accepted!'
			return
		}
		
		val file = if (req.path.equals('/')) {
			'/index.html'
		} else {
			if (!req.path.startsWith('/')) '/' + req.path else req.path 
		}
		
		logger.debug(file)
		req.response.sendFile(folder + file, 0, Long.MAX_VALUE)[
			if (!succeeded) {
				logger.error('File not found: {}', file)
				req.response.statusCode = 404
				req.response.end
			}
		]
	}
}