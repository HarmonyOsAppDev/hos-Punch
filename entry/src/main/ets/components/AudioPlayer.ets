import media from '@ohos.multimedia.media';
import { BusinessError } from '@ohos.base';
import common from '@ohos.app.ability.common';
import { activeConfig, AudioEvent, AudioEventParams, EventCode, music_config } from '../constants';
import { CountStatusType, MusicRepoType } from '../types';
import emitter from '@ohos.events.emitter';
import audio from '@ohos.multimedia.audio';
import wantAgent, { WantAgent } from '@ohos.app.ability.wantAgent';
import backgroundTaskManager from '@ohos.resourceschedule.backgroundTaskManager';
import AVSessionManager from '@ohos.multimedia.avsession';

@Component
export struct AudioPlayer {
  private avPlayer: media.AVPlayer | undefined = undefined;
  private count: number = 0;
  private isSeek: boolean = true; // 用于区分模式是否支持seek操作
  private musicRepo: MusicRepoType[]  = music_config;
  // 通过getContext方法，来获取page所在的UIAbility上下文。
  private context: Context = getContext(this);
  @State currentMusicIndex: number = 0;
  @State currentPlayStatus: CountStatusType = CountStatusType.UN_START;

  aboutToAppear(): void {
    emitter.on({eventId: EventCode.PLAY_AUDIO}, (params) => {
      const param = params.data as AudioEventParams;
      if (param.event === AudioEvent.PLAY) {
        this.avPlayer?.stop();
        this.avPlayer = undefined;
        this.playAudio(this.musicRepo[this.currentMusicIndex]?.src);
      }

      if ( param.event === AudioEvent.PAUSE) {
        this.pauseAudio();
      }
    })
  }

  async createSession() {
    let type: AVSessionManager.AVSessionType = 'audio';
    let session = await AVSessionManager.createAVSession(this.context,'SESSION_NAME', type);


    let metadata: AVSessionManager.AVMetadata = {
      assetId: '0', // 由应用指定，用于标识应用媒体库里的媒体
      title: this.musicRepo[this.currentMusicIndex]?.str,
      artist: '纯音乐'
    };

    let playbackState: AVSessionManager.AVPlaybackState = {
      state:AVSessionManager.PlaybackState.PLAYBACK_STATE_PAUSE,
      loopMode: AVSessionManager.LoopMode.LOOP_MODE_SINGLE,
      isFavorite: false
    };

    session.setAVPlaybackState(playbackState, (err) => {
      if (err) {
        console.error(`Failed to set AVPlaybackState. Code: ${err.code}, message: ${err.message}`);
      } else {
        console.info(`SetAVPlaybackState successfully`);
      }
    });

    session.setAVMetadata(metadata).then(() => {
      console.info(`SetAVMetadata successfully`);
    }).catch((err: BusinessError) => {
      console.error(`Failed to set AVMetadata. Code: ${err.code}, message: ${err.message}`);
    });


    // 激活接口要在元数据、控制命令注册完成之后再执行
    await session.activate();

    console.info(`session create done : sessionId : ${session.sessionId}`);
  }

  async startContinuousTask() {
    await this.createSession();

    let wantAgentInfo: wantAgent.WantAgentInfo = {

      wants: [
        {
          bundleName: "com.yuanzi.punchin",
          abilityName: "com.yuanzi.punchin.MainAbility"
        }
      ],
      // 指定点击通知栏消息后的动作是拉起ability
      operationType: wantAgent.OperationType.START_ABILITY,
      // 使用者自定义的一个私有值
      requestCode: 0,
      // 点击通知后，动作执行属性
      wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };

    // 通过wantAgent模块下getWantAgent方法获取WantAgent对象
    wantAgent.getWantAgent(wantAgentInfo).then((wantAgentObj: WantAgent) => {
      backgroundTaskManager.startBackgroundRunning(this.context,
        backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK, wantAgentObj).then(() => {
        console.info(`Succeeded in operationing startBackgroundRunning.`);
      }).catch((err: BusinessError) => {
        console.error(`Failed to operation startBackgroundRunning. Code is ${err.code}, message is ${err.message}`);
      });
    });
  }

  stopContinuousTask() {
    backgroundTaskManager.stopBackgroundRunning(this.context).then(() => {
      console.info(`Succeeded in operationing stopBackgroundRunning.`);
    }).catch((err: BusinessError) => {
      console.error(`Failed to operation stopBackgroundRunning. Code is ${err.code}, message is ${err.message}`);
    });
  }


  aboutToDisappear(): void {
    this.avPlayer = undefined;
    emitter.off(EventCode.PLAY_AUDIO)
    this.stopContinuousTask();
  }

  pauseAudio() {
    this.avPlayer?.stop();
    // this.stopContinuousTask();
  }

  setAVPlayerCallback(avPlayer: media.AVPlayer) {
    // seek操作结果回调函数
    avPlayer.on('seekDone', (seekDoneTime: number) => {
      console.info(`AVPlayer seek succeeded, seek time is ${seekDoneTime}`);
    })
    // error回调监听函数,当avPlayer在操作过程中出现错误时调用 reset接口触发重置流程
    avPlayer.on('error', (err: BusinessError) => {
      console.error(`Invoke avPlayer failed, code is ${err.code}, message is ${err.message}`);
      avPlayer.reset(); // 调用reset重置资源，触发idle状态
    })
    // 状态机变化回调函数
    avPlayer.on('stateChange', async (state: string, reason: media.StateChangeReason) => {
      switch (state) {
        case 'idle': // 成功调用reset接口后触发该状态机上报
          console.info('AVPlayer state idle called.');
          avPlayer.release(); // 调用release接口销毁实例对象
          break;
        case 'initialized': // avplayer 设置播放源后触发该状态上报
          console.info('AVPlayer state initialized called.');
          avPlayer.prepare();
          break;
        case 'prepared': // prepare调用成功后上报该状态机
          console.info('AVPlayer state prepared called.');
          avPlayer.audioInterruptMode = audio.InterruptMode.SHARE_MODE;
          avPlayer.play(); // 调用播放接口开始播放
          if (this.avPlayer) {
            this.avPlayer.loop = true;
          }
          break;
        case 'playing': // play成功调用后触发该状态机上报
          this.currentPlayStatus = CountStatusType.IN_PROCESS;
          console.info('AVPlayer state playing called.');
          if (this.count !== 0) {
            if (this.isSeek) {
              console.info('AVPlayer start to seek.');
              avPlayer.seek(avPlayer.duration); //seek到音频末尾
            } else {
              // 当播放模式不支持seek操作时继续播放到结尾
              console.info('AVPlayer wait to play end.');
            }
          } else {
            avPlayer.pause(); // 调用暂停接口暂停播放
          }
          this.count++;
          break;
        case 'paused': // pause成功调用后触发该状态机上报
          console.info('AVPlayer state paused called.');
          avPlayer.play(); // 再次播放接口开始播放
          break;
        case 'completed': // 播放结束后触发该状态机上报
          console.info('AVPlayer state completed called.');
          avPlayer.stop(); //调用播放结束接口
          break;
        case 'stopped': // stop接口成功调用后触发该状态机上报
          console.info('AVPlayer state stopped called.');
          this.currentPlayStatus = CountStatusType.IN_PAUSE;
          avPlayer.reset(); // 调用reset接口初始化avplayer状态
          break;
        case 'released':
          console.info('AVPlayer state released called.');
          break;
        default:
          console.info('AVPlayer state unknown called.');
          break;
      }
    })
  }


  async playAudio(audioSrc: string) {
    try {
      // 创建avPlayer实例对象
      this.avPlayer = await media.createAVPlayer();
      // 创建状态机变化回调函数
      this.setAVPlayerCallback(this.avPlayer);

      let context = getContext(this) as common.UIAbilityContext;

      let fileDescriptor = await context.resourceManager.getRawFd(audioSrc);

      let avFileDescriptor: media.AVFileDescriptor = { fd: fileDescriptor.fd, offset: fileDescriptor.offset, length: fileDescriptor.length };

      this.isSeek = false; // 支持seek操作
      // 为fdSrc赋值触发initialized状态机上报
      this.avPlayer.fdSrc = avFileDescriptor;

      this.startContinuousTask();
      // 为fdSrc赋值触发initialized状态机上报
    } catch (e) {
      console.error(`${JSON.stringify(e)}`)
    }
  }

  renderMusicText() {
     switch (this.currentPlayStatus) {
       case CountStatusType.UN_START:
         return "未开始播放";
       case CountStatusType.IN_PAUSE:
         return "暂停";
       case CountStatusType.IN_PROCESS:
         return "播放中";
       default:
         return "正在播放"
     }
  }

    build() {
      Row() {
        Row() {
          Row() {
            Row() {
              Image($r("app.media.music")).width(50).height(50).borderRadius(50).margin({left: 3, right: 5, top: 3, bottom: 3})

              Column() {
                Text(this.musicRepo[this.currentMusicIndex]?.str).fontSize(16).fontWeight(400).fontColor(activeConfig.active)
                Blank().height(3)
                Text(this.renderMusicText()).fontSize(12).fontWeight(400).fontColor(activeConfig.normal).opacity(0.6);
              }.alignItems(HorizontalAlign.Start)
            }

            Row() {

              Image($r([CountStatusType.UN_START, CountStatusType.IN_PAUSE ].includes(this.currentPlayStatus) ? 'app.media.playBtn' : "app.media.pause")).width(25).height(25).opacity(0.8).onClick(() => {
                if ([CountStatusType.UN_START, CountStatusType.IN_PAUSE].includes(this.currentPlayStatus)) {
                  this.playAudio(this.musicRepo[this.currentMusicIndex]?.src);
                } else {
                  this.pauseAudio();
                }
              })

              Blank().width(15)
              Image($r('app.media.chooseSong')).width(25).height(25).opacity(0.8).onClick(() => {
                TextPickerDialog.show({
                  range: this.musicRepo.map(item => item.str),
                  selected: this.currentMusicIndex,
                  onAccept: (value: TextPickerResult) => {
                    this.pauseAudio();
                    this.currentMusicIndex = value.index as number;

                    if ([CountStatusType.IN_PROCESS].includes(this.currentPlayStatus)) {
                      setTimeout(() => {
                        this.playAudio(this.musicRepo[this.currentMusicIndex]?.src);
                      }, 100)
                    }
                  },
                })
              })
            }.margin({right: 15})
          }.justifyContent(FlexAlign.SpaceBetween).width("100%")
        }.width("85%").borderRadius(25).backgroundColor("white")
        .shadow({
          radius: 15,
          color: "#d4d4d4"
        })

      }.position({ x: 0, y: "88%" }).width("100%").justifyContent(FlexAlign.Center)
    }
}