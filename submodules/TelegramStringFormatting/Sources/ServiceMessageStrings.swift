import Foundation
import UIKit
import Postbox
import TelegramCore
import SyncCore
import TelegramPresentationData
import TelegramUIPreferences
import TextFormat
import LocalizedPeerData
import Display
import Markdown

private let titleFont = Font.regular(13.0)
private let titleBoldFont = Font.bold(13.0)

private func peerMentionAttributes(primaryTextColor: UIColor, peerId: PeerId) -> MarkdownAttributeSet {
    return MarkdownAttributeSet(font: titleBoldFont, textColor: primaryTextColor, additionalAttributes: [TelegramTextAttributes.PeerMention: TelegramPeerMention(peerId: peerId, mention: "")])
}

private func peerMentionsAttributes(primaryTextColor: UIColor, peerIds: [(Int, PeerId?)]) -> [Int: MarkdownAttributeSet] {
    var result: [Int: MarkdownAttributeSet] = [:]
    for (index, peerId) in peerIds {
        if let peerId = peerId {
            result[index] = peerMentionAttributes(primaryTextColor: primaryTextColor, peerId: peerId)
        }
    }
    return result
}

public func plainServiceMessageString(strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, dateTimeFormat: PresentationDateTimeFormat, message: Message, accountPeerId: PeerId, forChatList: Bool) -> String? {
    return universalServiceMessageString(presentationData: nil, strings: strings, nameDisplayOrder: nameDisplayOrder, dateTimeFormat: dateTimeFormat, message: message, accountPeerId: accountPeerId, forChatList: forChatList)?.string
}

public func universalServiceMessageString(presentationData: (PresentationTheme, TelegramWallpaper)?, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, dateTimeFormat: PresentationDateTimeFormat, message: Message, accountPeerId: PeerId, forChatList: Bool) -> NSAttributedString? {
    var attributedString: NSAttributedString?
    
    let primaryTextColor: UIColor
    if let (theme, wallpaper) = presentationData {
        primaryTextColor = serviceMessageColorComponents(theme: theme, wallpaper: wallpaper).primaryText
    } else {
        primaryTextColor = .black
    }
    
    let bodyAttributes = MarkdownAttributeSet(font: titleFont, textColor: primaryTextColor, additionalAttributes: [:])
    
    for media in message.media {
        if let action = media as? TelegramMediaAction {
            let authorName = message.author?.displayTitle(strings: strings, displayOrder: nameDisplayOrder) ?? ""
            
            var isChannel = false
            if message.id.peerId.namespace == Namespaces.Peer.CloudChannel, let peer = message.peers[message.id.peerId] as? TelegramChannel, case .broadcast = peer.info {
                isChannel = true
            }
            
            switch action.action {
            case let .groupCreated(title):
                if isChannel {
                    attributedString = NSAttributedString(string: strings.Notification_CreatedChannel, font: titleFont, textColor: primaryTextColor)
                } else {
                    if forChatList {
                        attributedString = NSAttributedString(string: strings.Notification_CreatedGroup, font: titleFont, textColor: primaryTextColor)
                    } else {
                        attributedString = addAttributesToStringWithRanges(strings.Notification_CreatedChatWithTitle(authorName, title), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                    }
                }
            case let .addedMembers(peerIds):
                if let peerId = peerIds.first, peerId == message.author?.id {
                    if let peer = message.peers[message.id.peerId] as? TelegramChannel, case .broadcast = peer.info {
                        attributedString = addAttributesToStringWithRanges(strings.Notification_JoinedChannel(authorName), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, peerId)]))
                    } else {
                        attributedString = addAttributesToStringWithRanges(strings.Notification_JoinedChat(authorName), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, peerId)]))
                    }
                } else {
                    var attributePeerIds: [(Int, PeerId?)] = [(0, message.author?.id)]
                    let resultTitleString: (String, [(Int, NSRange)])
                    if peerIds.count == 1 {
                        attributePeerIds.append((1, peerIds.first))
                        resultTitleString = strings.Notification_Invited(authorName, peerDebugDisplayTitles(peerIds, message.peers))
                    } else {
                        resultTitleString = strings.Notification_InvitedMultiple(authorName, peerDebugDisplayTitles(peerIds, message.peers))
                    }
                    
                    attributedString = addAttributesToStringWithRanges(resultTitleString, body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: attributePeerIds))
                }
            case let .removedMembers(peerIds):
                if peerIds.first == message.author?.id {
                    if let peer = message.peers[message.id.peerId] as? TelegramChannel, case .broadcast = peer.info {
                        attributedString = addAttributesToStringWithRanges(strings.Notification_LeftChannel(authorName), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                    } else {
                        attributedString = addAttributesToStringWithRanges(strings.Notification_LeftChat(authorName), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                    }
                } else {
                    var attributePeerIds: [(Int, PeerId?)] = [(0, message.author?.id)]
                    if peerIds.count == 1 {
                        attributePeerIds.append((1, peerIds.first))
                    }
                    attributedString = addAttributesToStringWithRanges(strings.Notification_Kicked(authorName, peerDebugDisplayTitles(peerIds, message.peers)), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: attributePeerIds))
                }
            case let .photoUpdated(image):
                if authorName.isEmpty || isChannel {
                    if isChannel {
                        if let image = image {
                            if !image.videoRepresentations.isEmpty {
                                attributedString = NSAttributedString(string: strings.Channel_MessageVideoUpdated, font: titleFont, textColor: primaryTextColor)
                            } else {
                                attributedString = NSAttributedString(string: strings.Channel_MessagePhotoUpdated, font: titleFont, textColor: primaryTextColor)
                            }
                        } else {
                            attributedString = NSAttributedString(string: strings.Channel_MessagePhotoRemoved, font: titleFont, textColor: primaryTextColor)
                        }
                    } else {
                        if let image = image {
                            if !image.videoRepresentations.isEmpty {
                                attributedString = NSAttributedString(string: strings.Group_MessageVideoUpdated, font: titleFont, textColor: primaryTextColor)
                            } else {
                                attributedString = NSAttributedString(string: strings.Group_MessagePhotoUpdated, font: titleFont, textColor: primaryTextColor)
                            }
                        } else {
                            attributedString = NSAttributedString(string: strings.Group_MessagePhotoRemoved, font: titleFont, textColor: primaryTextColor)
                        }
                    }
                } else {
                    if let image = image {
                        if !image.videoRepresentations.isEmpty {
                            attributedString = addAttributesToStringWithRanges(strings.Notification_ChangedGroupVideo(authorName), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                        } else {
                            attributedString = addAttributesToStringWithRanges(strings.Notification_ChangedGroupPhoto(authorName), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                        }
                    } else {
                        attributedString = addAttributesToStringWithRanges(strings.Notification_RemovedGroupPhoto(authorName), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                    }
                }
            case let .titleUpdated(title):
                if authorName.isEmpty || isChannel {
                    attributedString = NSAttributedString(string: strings.Channel_MessageTitleUpdated(title).0, font: titleFont, textColor: primaryTextColor)
                } else {
                    attributedString = addAttributesToStringWithRanges(strings.Notification_ChangedGroupName(authorName, title), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                }
            case .pinnedMessageUpdated:
                enum PinnnedMediaType {
                    case text(String)
                    case game
                    case photo
                    case video
                    case round
                    case audio
                    case file
                    case gif
                    case sticker
                    case location
                    case contact
                    case poll(TelegramMediaPollKind)
                    case deleted
                }
                
                var pinnedMessage: Message?
                for attribute in message.attributes {
                    if let attribute = attribute as? ReplyMessageAttribute, let message = message.associatedMessages[attribute.messageId] {
                        pinnedMessage = message
                    }
                }
                
                var type: PinnnedMediaType
                if let pinnedMessage = pinnedMessage {
                    type = .text(pinnedMessage.text)
                    inner: for media in pinnedMessage.media {
                        if media is TelegramMediaGame {
                            type = .game
                            break inner
                        }
                        if let _ = media as? TelegramMediaImage {
                            type = .photo
                        } else if let file = media as? TelegramMediaFile {
                            type = .file
                            if file.isAnimated {
                                type = .gif
                            } else {
                                for attribute in file.attributes {
                                    switch attribute {
                                    case let .Video(_, _, flags):
                                        if flags.contains(.instantRoundVideo) {
                                            type = .round
                                        } else {
                                            type = .video
                                        }
                                        break inner
                                    case let .Audio(isVoice, _, _, _, _):
                                        if isVoice {
                                            type = .audio
                                        } else {
                                            type = .file
                                        }
                                        break inner
                                    case .Sticker:
                                        type = .sticker
                                        break inner
                                    case .Animated:
                                        break
                                    default:
                                        break
                                    }
                                }
                            }
                        } else if let _ = media as? TelegramMediaMap {
                            type = .location
                        } else if let _ = media as? TelegramMediaContact {
                            type = .contact
                        } else if let poll = media as? TelegramMediaPoll {
                            type = .poll(poll.kind)
                        }
                    }
                } else {
                    type = .deleted
                }
                
                switch type {
                case let .text(text):
                    var clippedText = text.replacingOccurrences(of: "\n", with: " ")
                    if clippedText.count > 14 {
                        clippedText = "\(clippedText[...clippedText.index(clippedText.startIndex, offsetBy: 14)])..."
                    }
                    let textWithRanges: (String, [(Int, NSRange)])
                    if clippedText.isEmpty {
                        textWithRanges = strings.Message_PinnedGenericMessage(authorName)
                    } else {
                        textWithRanges = strings.Notification_PinnedTextMessage(authorName, clippedText)
                    }
                    attributedString = addAttributesToStringWithRanges(textWithRanges, body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                case .game:
                    attributedString = addAttributesToStringWithRanges(strings.Message_AuthorPinnedGame(authorName), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                case .photo:
                    attributedString = addAttributesToStringWithRanges(strings.Notification_PinnedPhotoMessage(authorName), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                case .video:
                    attributedString = addAttributesToStringWithRanges(strings.Notification_PinnedVideoMessage(authorName), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                case .round:
                    attributedString = addAttributesToStringWithRanges(strings.Notification_PinnedRoundMessage(authorName), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                case .audio:
                    attributedString = addAttributesToStringWithRanges(strings.Notification_PinnedAudioMessage(authorName), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                case .file:
                    attributedString = addAttributesToStringWithRanges(strings.Notification_PinnedDocumentMessage(authorName), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                case .gif:
                    attributedString = addAttributesToStringWithRanges(strings.Notification_PinnedAnimationMessage(authorName), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                case .sticker:
                    attributedString = addAttributesToStringWithRanges(strings.Notification_PinnedStickerMessage(authorName), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                case .location:
                    attributedString = addAttributesToStringWithRanges(strings.Notification_PinnedLocationMessage(authorName), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                case .contact:
                    attributedString = addAttributesToStringWithRanges(strings.Notification_PinnedContactMessage(authorName), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                case let .poll(kind):
                    switch kind {
                    case .poll:
                        attributedString = addAttributesToStringWithRanges(strings.Notification_PinnedPollMessage(authorName), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                    case .quiz:
                        attributedString = addAttributesToStringWithRanges(strings.Notification_PinnedQuizMessage(authorName), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                    }
                case .deleted:
                    attributedString = addAttributesToStringWithRanges(strings.Message_PinnedGenericMessage(authorName), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                }
            case .joinedByLink:
                attributedString = addAttributesToStringWithRanges(strings.Notification_JoinedGroupByLink(authorName), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
            case .channelMigratedFromGroup, .groupMigratedToChannel:
                attributedString = NSAttributedString(string: "", font: titleFont, textColor: primaryTextColor)
            case let .messageAutoremoveTimeoutUpdated(timeout):
                let authorString: String
                if let author = messageMainPeer(message) {
                    authorString = author.compactDisplayTitle
                } else {
                    authorString = ""
                }
                
                let messagePeer = message.peers[message.id.peerId]
                
                if timeout > 0 {
                    let timeValue = timeIntervalString(strings: strings, value: timeout, preferLowerValue: true)
                    
                    /*
                     "Conversation.AutoremoveTimerSetUserYou" = "You set messages to automatically delete after %2$@.";
                     "Conversation.AutoremoveTimerSetUser" = "%1$@ set messages to automatically delete after %2$@.";
                     "Conversation.AutoremoveTimerRemovedUserYou" = "You disabled the self-destruct timer";
                     "Conversation.AutoremoveTimerRemovedUser" = "%1$@ disabled the self-destruct timer";
                     "Conversation.AutoremoveTimerSetGroup" = "Messages will automatically delete after %1$@.";
                     "Conversation.AutoremoveTimerRemovedGroup" = "Self-destruct timer was disabled";
                     */
                    
                    let string: String
                    if let _ = messagePeer as? TelegramUser {
                        if message.author?.id == accountPeerId {
                            string = strings.Conversation_AutoremoveTimerSetUserYou(timeValue).0
                        } else {
                            string = strings.Conversation_AutoremoveTimerSetUser(authorString, timeValue).0
                        }
                    } else if let _ = messagePeer as? TelegramGroup {
                        string = strings.Conversation_AutoremoveTimerSetGroup(timeValue).0
                    } else if let channel = messagePeer as? TelegramChannel {
                        if case .group = channel.info {
                            string = strings.Conversation_AutoremoveTimerSetGroup(timeValue).0
                        } else {
                            string = strings.Conversation_AutoremoveTimerSetChannel(timeValue).0
                        }
                    } else {
                        if message.author?.id == accountPeerId {
                            string = strings.Notification_MessageLifetimeChangedOutgoing(timeValue).0
                        } else {
                            string = strings.Notification_MessageLifetimeChanged(authorString, timeValue).0
                        }
                    }
                    attributedString = NSAttributedString(string: string, font: titleFont, textColor: primaryTextColor)
                } else {
                    let string: String
                    if let _ = messagePeer as? TelegramUser {
                        if message.author?.id == accountPeerId {
                            string = strings.Conversation_AutoremoveTimerRemovedUserYou
                        } else {
                            string = strings.Conversation_AutoremoveTimerRemovedUser(authorString).0
                        }
                    } else if let _ = messagePeer as? TelegramGroup {
                        string = strings.Conversation_AutoremoveTimerRemovedGroup
                    } else if let channel = messagePeer as? TelegramChannel {
                        if case .group = channel.info {
                            string = strings.Conversation_AutoremoveTimerRemovedGroup
                        } else {
                            string = strings.Conversation_AutoremoveTimerRemovedChannel
                        }
                    } else {
                        if message.author?.id == accountPeerId {
                            string = strings.Notification_MessageLifetimeRemovedOutgoing
                        } else {
                            string = strings.Notification_MessageLifetimeRemoved(authorString).0
                        }
                    }
                    attributedString = NSAttributedString(string: string, font: titleFont, textColor: primaryTextColor)
                }
            case .historyCleared:
                break
            case .historyScreenshot:
                let text: String
                if message.effectivelyIncoming(accountPeerId) {
                    text = strings.Notification_SecretChatMessageScreenshot(message.author?.compactDisplayTitle ?? "").0
                } else {
                    text = strings.Notification_SecretChatMessageScreenshotSelf
                }
                attributedString = NSAttributedString(string: text, font: titleFont, textColor: primaryTextColor)
            case let .gameScore(gameId: _, score):
                var gameTitle: String?
                inner: for attribute in message.attributes {
                    if let attribute = attribute as? ReplyMessageAttribute, let message = message.associatedMessages[attribute.messageId] {
                        for media in message.media {
                            if let game = media as? TelegramMediaGame {
                                gameTitle = game.title
                                break inner
                            }
                        }
                    }
                }
                
                var baseString: String
                if message.author?.id == accountPeerId {
                    if let _ = gameTitle {
                        baseString = strings.ServiceMessage_GameScoreSelfExtended(score)
                    } else {
                        baseString = strings.ServiceMessage_GameScoreSelfSimple(score)
                    }
                } else {
                    if let _ = gameTitle {
                        baseString = strings.ServiceMessage_GameScoreExtended(score)
                    } else {
                        baseString = strings.ServiceMessage_GameScoreSimple(score)
                    }
                }
                let baseStringValue = baseString as NSString
                var ranges: [(Int, NSRange)] = []
                if baseStringValue.range(of: "{name}").location != NSNotFound {
                    ranges.append((0, baseStringValue.range(of: "{name}")))
                }
                if baseStringValue.range(of: "{game}").location != NSNotFound {
                    ranges.append((1, baseStringValue.range(of: "{game}")))
                }
                ranges.sort(by: { $0.1.location < $1.1.location })
                
                var argumentAttributes = peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)])
                argumentAttributes[1] = MarkdownAttributeSet(font: titleBoldFont, textColor: primaryTextColor, additionalAttributes: [:])
                attributedString = addAttributesToStringWithRanges(formatWithArgumentRanges(baseString, ranges, [authorName, gameTitle ?? ""]), body: bodyAttributes, argumentAttributes: argumentAttributes)
            case let .paymentSent(currency, totalAmount):
                var invoiceMessage: Message?
                for attribute in message.attributes {
                    if let attribute = attribute as? ReplyMessageAttribute, let message = message.associatedMessages[attribute.messageId] {
                        invoiceMessage = message
                    }
                }
                
                var invoiceTitle: String?
                if let invoiceMessage = invoiceMessage {
                    for media in invoiceMessage.media {
                        if let invoice = media as? TelegramMediaInvoice {
                            invoiceTitle = invoice.title
                        }
                    }
                }
                
                if let invoiceTitle = invoiceTitle {
                    let botString: String
                    if let peer = messageMainPeer(message) {
                        botString = peer.compactDisplayTitle
                    } else {
                        botString = ""
                    }
                    let mutableString = NSMutableAttributedString()
                    mutableString.append(NSAttributedString(string: strings.Notification_PaymentSent, font: titleFont, textColor: primaryTextColor))
                    
                    var range = NSRange(location: NSNotFound, length: 0)
                    
                    range = (mutableString.string as NSString).range(of: "{amount}")
                    if range.location != NSNotFound {
                        mutableString.replaceCharacters(in: range, with: NSAttributedString(string: formatCurrencyAmount(totalAmount, currency: currency), font: titleBoldFont, textColor: primaryTextColor))
                    }
                    range = (mutableString.string as NSString).range(of: "{name}")
                    if range.location != NSNotFound {
                        mutableString.replaceCharacters(in: range, with: NSAttributedString(string: botString, font: titleBoldFont, textColor: primaryTextColor))
                    }
                    range = (mutableString.string as NSString).range(of: "{title}")
                    if range.location != NSNotFound {
                        mutableString.replaceCharacters(in: range, with: NSAttributedString(string: invoiceTitle, font: titleFont, textColor: primaryTextColor))
                    }
                    attributedString = mutableString
                } else {
                    attributedString = NSAttributedString(string: strings.Message_PaymentSent(formatCurrencyAmount(totalAmount, currency: currency)).0, font: titleFont, textColor: primaryTextColor)
                }
            case let .phoneCall(_, discardReason, _, _):
                var titleString: String
                let incoming: Bool
                if message.flags.contains(.Incoming) {
                    titleString = strings.Notification_CallIncoming
                    incoming = true
                } else {
                    titleString = strings.Notification_CallOutgoing
                    incoming = false
                }
                if let discardReason = discardReason {
                    switch discardReason {
                    case .disconnect:
                        titleString = strings.Notification_CallCanceled
                    case .missed, .busy:
                        titleString = incoming ? strings.Notification_CallMissed : strings.Notification_CallCanceled
                    case .hangup:
                        break
                    }
                }
                attributedString = NSAttributedString(string: titleString, font: titleFont, textColor: primaryTextColor)
            case let .groupPhoneCall(_, _, scheduleDate, duration):
                if let scheduleDate = scheduleDate {
                    if message.author?.id.namespace == Namespaces.Peer.CloudChannel {
                        let titleString = humanReadableStringForTimestamp(strings: strings, dateTimeFormat: dateTimeFormat, timestamp: scheduleDate, alwaysShowTime: true, allowYesterday: false, format: HumanReadableStringFormat(dateFormatString: { strings.Notification_VoiceChatScheduledChannel($0).0 }, tomorrowFormatString: { strings.Notification_VoiceChatScheduledTomorrowChannel($0).0 }, todayFormatString: { strings.Notification_VoiceChatScheduledTodayChannel($0).0 }, yesterdayFormatString: { $0 }))
                        attributedString = NSAttributedString(string: titleString, font: titleFont, textColor: primaryTextColor)
                    } else {
                        let timeString = humanReadableStringForTimestamp(strings: strings, dateTimeFormat: dateTimeFormat, timestamp: scheduleDate)
                        let attributePeerIds: [(Int, PeerId?)] = [(0, message.author?.id)]
                        let titleString = strings.Notification_VoiceChatScheduled(authorName, timeString)
                        attributedString = addAttributesToStringWithRanges(titleString, body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: attributePeerIds))
                    }
                } else if let duration = duration {
                    let titleString = strings.Notification_VoiceChatEnded(callDurationString(strings: strings, value: duration)).0
                    attributedString = NSAttributedString(string: titleString, font: titleFont, textColor: primaryTextColor)
                } else {
                    if message.author?.id.namespace == Namespaces.Peer.CloudChannel {
                        let titleString = strings.Notification_VoiceChatStartedChannel
                        attributedString =  NSAttributedString(string: titleString, font: titleFont, textColor: primaryTextColor)
                    } else {
                        let attributePeerIds: [(Int, PeerId?)] = [(0, message.author?.id)]
                        let titleString = strings.Notification_VoiceChatStarted(authorName)
                        attributedString = addAttributesToStringWithRanges(titleString, body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: attributePeerIds))
                    }
                }
            case let .customText(text, entities):
                attributedString = stringWithAppliedEntities(text, entities: entities, baseColor: primaryTextColor, linkColor: primaryTextColor, baseFont: titleFont, linkFont: titleBoldFont, boldFont: titleBoldFont, italicFont: titleFont, boldItalicFont: titleBoldFont, fixedFont: titleFont, blockQuoteFont: titleFont, underlineLinks: false)
            case let .botDomainAccessGranted(domain):
                attributedString = NSAttributedString(string: strings.AuthSessions_Message(domain).0, font: titleFont, textColor: primaryTextColor)
            case let .botSentSecureValues(types):
                var typesString = ""
                var hasIdentity = false
                var hasAddress = false
                for type in types {
                    if !typesString.isEmpty {
                        typesString.append(", ")
                    }
                    switch type {
                    case .personalDetails:
                        typesString.append(strings.Notification_PassportValuePersonalDetails)
                    case .passport, .internalPassport, .driversLicense, .idCard:
                        if !hasIdentity {
                            typesString.append(strings.Notification_PassportValueProofOfIdentity)
                            hasIdentity = true
                        }
                    case .address:
                        typesString.append(strings.Notification_PassportValueAddress)
                    case .bankStatement, .utilityBill, .rentalAgreement, .passportRegistration, .temporaryRegistration:
                        if !hasAddress {
                            typesString.append(strings.Notification_PassportValueProofOfAddress)
                            hasAddress = true
                        }
                    case .phone:
                        typesString.append(strings.Notification_PassportValuePhone)
                    case .email:
                        typesString.append(strings.Notification_PassportValueEmail)
                    }
                }
                attributedString = NSAttributedString(string: strings.Notification_PassportValuesSentMessage(message.peers[message.id.peerId]?.compactDisplayTitle ?? "", typesString).0, font: titleFont, textColor: primaryTextColor)
            case .peerJoined:
                attributedString = addAttributesToStringWithRanges(strings.Notification_Joined(authorName), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
            case .phoneNumberRequest:
                attributedString = nil
            case let .geoProximityReached(fromId, toId, distance):
                let distanceString = stringForDistance(strings: strings, distance: Double(distance))
                if fromId == accountPeerId {
                    attributedString = addAttributesToStringWithRanges(strings.Notification_ProximityYouReached(distanceString, message.peers[toId]?.displayTitle(strings: strings, displayOrder: nameDisplayOrder) ?? ""), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(1, toId)]))
                } else if toId == accountPeerId {
                    attributedString = addAttributesToStringWithRanges(strings.Notification_ProximityReachedYou(message.peers[fromId]?.displayTitle(strings: strings, displayOrder: nameDisplayOrder) ?? "", distanceString), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, fromId)]))
                } else {
                    attributedString = addAttributesToStringWithRanges(strings.Notification_ProximityReached(message.peers[fromId]?.displayTitle(strings: strings, displayOrder: nameDisplayOrder) ?? "", distanceString, message.peers[toId]?.displayTitle(strings: strings, displayOrder: nameDisplayOrder) ?? ""), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, fromId), (2, toId)]))
                }
            case let .inviteToGroupPhoneCall(_, _, peerIds):
                var attributePeerIds: [(Int, PeerId?)] = [(0, message.author?.id)]
                let resultTitleString: (String, [(Int, NSRange)])
                if peerIds.count == 1 {
                    if peerIds[0] == accountPeerId {
                        attributePeerIds.append((1, peerIds.first))
                        resultTitleString = strings.Notification_VoiceChatInvitationForYou(authorName)
                    } else {
                        attributePeerIds.append((1, peerIds.first))
                        resultTitleString = strings.Notification_VoiceChatInvitation(authorName, peerDebugDisplayTitles(peerIds, message.peers))
                    }
                } else {
                    resultTitleString = strings.Notification_VoiceChatInvitation(authorName, peerDebugDisplayTitles(peerIds, message.peers))
                }
                
                attributedString = addAttributesToStringWithRanges(resultTitleString, body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: attributePeerIds))
            case .unknown:
                attributedString = nil
            }
            
            break
        } else if let expiredMedia = media as? TelegramMediaExpiredContent {
            switch expiredMedia.data {
            case .image:
                attributedString = NSAttributedString(string: strings.Message_ImageExpired, font: titleFont, textColor: primaryTextColor)
            case .file:
                attributedString = NSAttributedString(string: strings.Message_VideoExpired, font: titleFont, textColor: primaryTextColor)
            }
        }
    }
    
    return attributedString
}
