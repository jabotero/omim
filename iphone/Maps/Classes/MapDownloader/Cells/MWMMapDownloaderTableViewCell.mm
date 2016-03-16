#import "Common.h"
#import "MWMCircularProgress.h"
#import "MWMMapDownloaderTableViewCell.h"

#include "Framework.h"

@interface MWMMapDownloaderTableViewCell () <MWMCircularProgressProtocol>

@property (nonatomic) MWMCircularProgress * progress;
@property (weak, nonatomic) IBOutlet UIView * stateWrapper;
@property (weak, nonatomic) IBOutlet UILabel * title;
@property (weak, nonatomic) IBOutlet UILabel * downloadSize;

@end

@implementation MWMMapDownloaderTableViewCell
{
  storage::TCountryId m_countryId;
}

+ (CGFloat)estimatedHeight
{
  return 52.0;
}

- (void)awakeFromNib
{
  [super awakeFromNib];
  m_countryId = kInvalidCountryId;
}

- (void)prepareForReuse
{
  [super prepareForReuse];
  m_countryId = kInvalidCountryId;
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  if (isIOS7)
  {
    self.title.preferredMaxLayoutWidth = floor(self.title.width);
    self.downloadSize.preferredMaxLayoutWidth = floor(self.downloadSize.width);
    [super layoutSubviews];
  }
}

#pragma mark - Config

- (void)config:(storage::NodeAttrs const &)nodeAttrs
{
  [self configProgress:nodeAttrs];
  self.title.text = @(nodeAttrs.m_nodeLocalName.c_str());
  self.downloadSize.text = formattedSize(nodeAttrs.m_mwmSize);
}

- (void)configProgress:(const storage::NodeAttrs &)nodeAttrs
{
  MWMCircularProgress * progress = self.progress;
  switch (nodeAttrs.m_status)
  {
    case NodeStatus::NotDownloaded:
    case NodeStatus::Partly:
    {
      auto const affectedStates = {MWMCircularProgressStateNormal, MWMCircularProgressStateSelected};
      [progress setImage:[UIImage imageNamed:@"ic_download"] forStates:affectedStates];
      [progress setColoring:MWMButtonColoringBlack forStates:affectedStates];
      progress.state = MWMCircularProgressStateNormal;
      break;
    }
    case NodeStatus::Downloading:
    {
      auto const & prg = nodeAttrs.m_downloadingProgress;
      progress.progress = static_cast<CGFloat>(prg.first) / prg.second;
      break;
    }
    case NodeStatus::InQueue:
      progress.state = MWMCircularProgressStateSpinner;
      break;
    case NodeStatus::Undefined:
    case NodeStatus::Error:
      progress.state = MWMCircularProgressStateFailed;
      break;
    case NodeStatus::OnDisk:
      progress.state = MWMCircularProgressStateCompleted;
      break;
    case NodeStatus::OnDiskOutOfDate:
    {
      auto const affectedStates = {MWMCircularProgressStateNormal, MWMCircularProgressStateSelected};
      [progress setImage:[UIImage imageNamed:@"ic_update"] forStates:affectedStates];
      [progress setColoring:MWMButtonColoringOther forStates:affectedStates];
      progress.state = MWMCircularProgressStateNormal;
      break;
    }
  }
}

#pragma mark - MWMFrameworkStorageObserver

- (void)processCountryEvent:(TCountryId const &)countryId
{
  if (countryId != m_countryId)
    return;
  storage::NodeAttrs nodeAttrs;
  GetFramework().Storage().GetNodeAttrs(m_countryId, nodeAttrs);
  [self config:nodeAttrs];
}

- (void)processCountry:(TCountryId const &)countryId progress:(TLocalAndRemoteSize const &)progress
{
  if (countryId != m_countryId)
    return;
  self.progress.progress = static_cast<CGFloat>(progress.first) / progress.second;
}

#pragma mark - MWMCircularProgressProtocol

- (void)progressButtonPressed:(nonnull MWMCircularProgress *)progress
{
  storage::NodeAttrs nodeAttrs;
  GetFramework().Storage().GetNodeAttrs(m_countryId, nodeAttrs);
  switch (nodeAttrs.m_status)
  {
    case NodeStatus::NotDownloaded:
    case NodeStatus::Partly:
      [self.delegate downloadNode:m_countryId];
      break;
    case NodeStatus::Undefined:
    case NodeStatus::Error:
      [self.delegate retryDownloadNode:m_countryId];
      break;
    case NodeStatus::OnDiskOutOfDate:
      [self.delegate updateNode:m_countryId];
      break;
    case NodeStatus::Downloading:
    case NodeStatus::InQueue:
      [self.delegate cancelNode:m_countryId];
      break;
    case NodeStatus::OnDisk:
      break;
  }
}

#pragma mark - Properties

- (void)setCountryId:(storage::TCountryId const &)countryId
{
  if (m_countryId == countryId)
    return;
  m_countryId = countryId;
  storage::NodeAttrs nodeAttrs;
  GetFramework().Storage().GetNodeAttrs(m_countryId, nodeAttrs);
  [self config:nodeAttrs];
}

- (MWMCircularProgress *)progress
{
  if (!_progress && !self.isHeightCell)
  {
    _progress = [MWMCircularProgress downloaderProgressForParentView:self.stateWrapper];
    _progress.delegate = self;
  }
  return _progress;
}

@end