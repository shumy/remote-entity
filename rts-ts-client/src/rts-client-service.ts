import { Observable, Subscriber } from 'rxjs/Rx';

import { Pipeline, PipeResource } from './rts-pipeline'
import { MessageBus, Subscription, IMessage, TYP } from './rts-messagebus'
import { IAuthManager } from './rts-auth'

export interface IServiceClientFactory {
  serviceClient: ServiceClient
}

export class ClientRouter implements IServiceClientFactory {
  private _ready = false
  private url: string

  private resource: PipeResource = null
  private websocket: WebSocket
  private _serviceClient: ServiceClient

  public authMgr: IAuthManager

  get bus() { return this.pipeline.mb }

  constructor(public server: string, public client: string, public pipeline: Pipeline = new Pipeline) {
    this.url = server + '?client=' + client
    this._serviceClient = new ServiceClient(this.bus, this.server, this.client)

    this.bus.subscribe(server, _ => this.send(_))
    this.connect()
  }

  ready() { this._ready = true }

  createProxy(srvName: string) {
    return this._serviceClient.create(srvName)
  }

  get serviceClient() {
    return this._serviceClient
  }

  connect() {
    console.log('TRY-OPEN: ', this.url)
    this.websocket = new WebSocket(this.url)

    this.websocket.onopen = (evt) => {
      this.onOpen()
    }

    this.websocket.onclose = () => {
      this.close()
      setTimeout(() => this.connect(), 3000) // try reconnection
    }

    this.websocket.onerror = (evt) => {
      console.log('WS-ERROR: ', evt)
    }

    this.websocket.onmessage = (evt) => {
      let msg = JSON.parse(evt.data)
      console.log('RECEIVED: ', msg)
      this.receive(msg)
    }
  }

  close() {
    if (this.resource !== null) {
      this.resource.release
      this.resource = null

      if (this.websocket !== null) {
        this.websocket.close()
        this.websocket = null
      }
    }
  }

  private send(msg: any) {
    if (this.authMgr && this.authMgr.isLogged) {
      //add auth headers, do not override...
      if (!msg.headers) msg.headers = {}

      msg.headers.auth = this.authMgr.authInfo.auth
      msg.headers.token = this.authMgr.authInfo.token
    }
    
    this.waitReady(() => {
      console.log('SEND: ', msg)
      this.websocket.send(JSON.stringify(msg))
    })
  }

  private waitReady(callback: () => void) {
    if (this.websocket.readyState === 1) {
      callback()
    } else {
      setTimeout(() => this.waitReady(callback))
    }
  }

  private onOpen() {
    this.resource = this.pipeline.createResource(this.server, (msg) => this.send(msg), () => this.close())
  }

  private receive(msg: any) {
    this.resource.process(msg, _ => _.setObject('IServiceClientFactory', this))
  }
}

declare let Proxy: any

export class ServiceClient {
  static clientSeq = 0

  private uuid: string
  private msgID = 0		      //increment for every new message

  constructor(private bus: MessageBus, private server: string, client: string) {
    ServiceClient.clientSeq++
    this.uuid = ServiceClient.clientSeq + ':' + client
  }

  create(srvName: string): any {
    let srvPath = 'srv:' + srvName
    let srvClient = this

    let handler = {
      get(target, srvMeth, receiver) {
        //console.log('GET-METH: ', srvMeth)
        return (...srvArgs) => {
          return new Promise((resolve, reject) => {
            srvClient.msgID++
            let sendMsg: IMessage = { id: srvClient.msgID, clt: srvClient.uuid, path: srvPath, cmd: srvMeth, args: srvArgs }

            console.log('PROXY-SEND: ', sendMsg)
            srvClient.bus.send(srvClient.server, sendMsg, (replyMsg) => {
              console.log('PROXY-REPLY: ', replyMsg)
              if (replyMsg.cmd === TYP.CMD_OK) {
                resolve(replyMsg.res)
              } else if (replyMsg.cmd === TYP.CMD_OBSERVABLE) {
                resolve(new RemoteObservable(srvClient.bus, replyMsg.res))
              } else {
                reject(replyMsg.res)
              }
            })
          })
        }
      }
    }

    return new Proxy({}, handler)
  }
}

class RemoteObservable extends Observable<any> {
  private data = []
  private isComplete = false

  private listener: Subscription
  private sub: Subscriber<any>

  constructor(bus: MessageBus, address: string) {
    super(sub => {
      this.sub = sub
      
      if (this.data.length !== 0) {
        this.data.forEach(entry => {
          if (entry[0] === true) {
            this.sub.next(entry[1])
          } else {
            this.sub.error(entry[1])
            this.listener.remove()
          }
        })
      }

      if (this.isComplete) {
        this.sub.complete()
        this.listener.remove()
      }
    })
    
    //TODO: timeout for responses? -> remove listener...
    this.listener = bus.subscribe(address, msg => {
      if (msg.cmd === TYP.CMD_OK) {
        this.processNext(msg.res)
      } else if (msg.cmd === TYP.CMD_COMPLETE) {
        this.processComplete()
      } else if (msg.cmd === TYP.CMD_ERROR) {
        this.processError(msg.res)
      }
    })
  }

  private processNext(item: any) {
    if (this.sub)
      this.sub.next(item)
    else
      this.data.push([true, item])
  }

  private processComplete() {
    if (this.sub) {
      this.sub.complete()
      this.listener.remove()
    } else {
      this.isComplete = true
    }
  }

  private processError(error: any) {
    if (this.sub) {
      this.sub.error(error)
      this.listener.remove()
    } else
      this.data.push([false, error])
  }
}