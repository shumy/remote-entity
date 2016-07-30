package rt.plugin.service.an

import java.lang.annotation.Retention
import java.lang.annotation.Target
import org.eclipse.xtend.lib.macro.AbstractInterfaceProcessor
import org.eclipse.xtend.lib.macro.Active
import org.eclipse.xtend.lib.macro.TransformationContext
import org.eclipse.xtend.lib.macro.declaration.MutableInterfaceDeclaration
import rt.async.promise.Promise

@Target(TYPE)
@Retention(RUNTIME)
@Active(ServiceProxyProcessor)
annotation ServiceProxy {
	Class<?> value
}

class ServiceProxyProcessor extends AbstractInterfaceProcessor {
	
	override doTransform(MutableInterfaceDeclaration inter, extension TransformationContext ctx) {
		val anno = inter.findAnnotation(ServiceProxy.findTypeGlobally)
		val client = anno.getClassValue('value')
		
		client.declaredResolvedMethods.forEach[ meth |
			val interMeth = meth.declaration
			val annoPublic = interMeth.findAnnotation(Public.findTypeGlobally)
			val isNotification = if (annoPublic != null) annoPublic.getBooleanValue('notif') else false
			
			inter.addMethod(interMeth.simpleName)[ proxyMeth |
				interMeth.parameters.forEach[ proxyMeth.addParameter(simpleName, type) ]
				if (!isNotification)
					proxyMeth.returnType = Promise.newTypeReference(interMeth.returnType)
				
				val anRef = Public.newAnnotationReference[
					setClassValue('retType', interMeth.returnType)
					setBooleanValue('notif', isNotification)
				]
				
				proxyMeth.addAnnotation(anRef)
			]
		]
	}
}