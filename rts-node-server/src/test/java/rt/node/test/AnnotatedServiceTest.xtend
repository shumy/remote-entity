package rt.node.test

import rt.node.Registry
import io.vertx.ext.unit.junit.VertxUnitRunner
import org.junit.runner.RunWith
import org.junit.Rule
import io.vertx.ext.unit.junit.RunTestOnContext
import org.junit.Before
import io.vertx.ext.unit.TestContext
import org.junit.Test
import rt.node.pipeline.use.ValidatorInterceptor
import rt.node.AnnotatedService
import io.vertx.core.json.JsonObject
import rt.node.pipeline.Pipeline

@RunWith(VertxUnitRunner)
class AnnotatedServiceTest {
	Registry registry
	Pipeline pipeline
	
	@Rule
	public val rule = new RunTestOnContext
	
	@Before
	def void init(TestContext ctx) {
		this.registry = new Registry("domain", rule.vertx)
		
		this.pipeline = registry.createPipeline => [
			addInterceptor(new ValidatorInterceptor)
			addService(new AnnotatedService)
			failHandler = [ ctx.fail(it) ]
		]
	}
	
	@Test(timeout = 1000)
	def void serviceHelloCall(TestContext ctx) {
		val sync = ctx.async(1)

		println('serviceHelloCall')
		val msg = new JsonObject('{ "id":1, "cmd":"hello", "client":"source", "path":"srv:test", "args":["Micael", "Pedrosa"] }')
		val reply = new JsonObject('{ "id":1, "cmd":"ok", "client":"source", "result":{ "type":"string", "value":"Hello Micael Pedrosa!" } }')
		
		val r = pipeline.createResource("uid", "r", [ ctx.assertEquals(it, reply) sync.countDown ], null)
		r.process(msg)
	}
	
	@Test(timeout = 1000)
	def void serviceSumCall(TestContext ctx) {
		val sync = ctx.async(1)

		println('serviceSumCall')
		val msg = new JsonObject('{ "id":1, "cmd":"sum", "client":"source", "path":"srv:test", "args":[1, 2, 1.5, 2.5] }')
		val reply = new JsonObject('{ "id":1, "cmd":"ok", "client":"source", "result":{ "type":"double", "value":7 } }')
		
		val r = pipeline.createResource("uid", "r", [ ctx.assertEquals(it, reply) sync.countDown ], null)
		r.process(msg)
	}
	
	@Test(timeout = 1000)
	def void serviceAlexBrothersCall(TestContext ctx) {
		val sync = ctx.async(1)

		println('serviceAlexBrothersCall')
		val msg = new JsonObject('{ "id":1, "cmd":"alexBrothers", "client":"source", "path":"srv:test" }')
		val reply = new JsonObject('{ "id":1, "cmd":"ok", "client":"source", "result":{ "type":"map", "value":{ "name":"Alex", "brothers":["Jorge", "Mary"], "age":35 } } }')
		
		val r = pipeline.createResource("uid", "r", [ ctx.assertEquals(it, reply) sync.countDown ], null)
		r.process(msg)
	}
}