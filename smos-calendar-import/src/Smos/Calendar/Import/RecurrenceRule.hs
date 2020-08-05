{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}

module Smos.Calendar.Import.RecurrenceRule where

import Data.List.NonEmpty (NonEmpty (..))
import qualified Data.List.NonEmpty as NE
import Data.Maybe
import Data.Time
import Data.Validity
import Data.Validity.Time ()
import GHC.Generics (Generic)
import Smos.Calendar.Import.UnresolvedTimestamp

-- Recurrence rules are defined here: https://tools.ietf.org/html/rfc5545#section-3.3.10
--
-- There is more info in section 3.8.5.3: Recurrence rules
data RRule
  = RRule
      { -- | The FREQ rule part identifies the type of recurrence rule.
        --
        -- This rule part MUST be specified in the recurrence rule.  Valid
        -- values include SECONDLY, to specify repeating events based on an
        -- interval of a second or more; MINUTELY, to specify repeating events
        -- based on an interval of a minute or more; HOURLY, to specify
        -- repeating events based on an interval of an hour or more; DAILY, to
        -- specify repeating events based on an interval of a day or more;
        -- WEEKLY, to specify repeating events based on an interval of a week
        -- or more; MONTHLY, to specify repeating events based on an interval
        -- of a month or more; and YEARLY, to specify repeating events based on
        -- an interval of a year or more.
        rRuleFrequency :: !Frequency,
        -- | The INTERVAL rule part contains a positive integer representing at which intervals the recurrence rule repeats.
        --
        -- The default value is "1", meaning every second for a SECONDLY rule,
        -- every minute for a MINUTELY rule, every hour for an HOURLY rule,
        -- every day for a DAILY rule, every week for a WEEKLY rule, every
        -- month for a MONTHLY rule, and every year for a YEARLY rule.  For
        -- example, within a DAILY rule, a value of "8" means every eight days.
        --
        -- Note: We chose 'Word' because the intervals are always positive.
        -- We also did not chose 'Maybe Word' because that would have two ways to represent the default value.
        rRuleInterval :: !Word,
        -- | This is one haskell-field based on two fields in the spec: UNTIL and COUNT together.
        --
        -- This because the spec says
        --
        -- > "The UNTIL or COUNT rule parts are OPTIONAL, but they MUST NOT occur in the same 'recur'."
        --
        -- See 'UntilCount' for more info.
        rRuleUntilCount :: !UntilCount,
        -- | The BYSECOND rule part specifies a COMMA-separated list of seconds within a minute.
        --
        -- Valid values are 0 to 60.
        rRuleBySecond :: !(Maybe (NonEmpty Word)),
        -- | The BYMINUTE rule part specifies a COMMA-separated list of minutes within an hour.
        --
        -- Valid values are 0 to 59.
        rRuleByMinute :: !(Maybe (NonEmpty Word)),
        -- | The BYHOUR rule part specifies a COMMA-separated list of hours of the day.
        --
        -- Valid values are 0 to 23.
        rRuleByHour :: !(Maybe (NonEmpty Word)),
        -- | The BYDAY rule part specifies a COMMA-separated list of days of the week; [...]
        --
        -- The BYDAY rule part MUST NOT be specified with a numeric value when
        -- the FREQ rule part is not set to MONTHLY or YEARLY.  Furthermore,
        -- the BYDAY rule part MUST NOT be specified with a numeric value with
        -- the FREQ rule part set to YEARLY when the BYWEEKNO rule part is
        -- specified.
        --
        -- See 'ByDay' as well.
        rRuleByDay :: !(Maybe (NonEmpty ByDay)),
        -- | The BYMONTHDAY rule part specifies a COMMA-separated list of days of the month.
        --
        -- Valid values are 1 to 31 or -31 to -1.  For example, -10 represents
        -- the tenth to the last day of the month.  The BYMONTHDAY rule part
        -- MUST NOT be specified when the FREQ rule part is set to WEEKLY
        rRuleByMonthDay :: !(Maybe (NonEmpty Int)),
        -- | The BYYEARDAY rule part specifies a COMMA-separated list of days of the year.
        --
        -- Valid values are 1 to 366 or -366 to -1.  For
        -- example, -1 represents the last day of the year (December 31st)
        -- and -306 represents the 306th to the last day of the year (March
        -- 1st).  The BYYEARDAY rule part MUST NOT be specified when the FREQ
        -- rule part is set to DAILY, WEEKLY, or MONTHLY.
        rRuleByYearDay :: !(Maybe (NonEmpty Int))
      }
  deriving (Show, Eq, Generic)

-- TODO put this where we actually do the ignoring
-- The BYSECOND, BYMINUTE and BYHOUR rule parts MUST NOT be specified when the
-- associated "DTSTART" property has a DATE value type.  These rule parts MUST
-- be ignored in RECUR value that violate the above requirement (e.g.,
-- generated by applications that pre-date this revision of iCalendar).

instance Validity RRule where
  validate rRule@RRule {..} =
    mconcat
      [ genericValidate rRule,
        declare "The interval is greater than zero" $ rRuleInterval >= 1,
        decorateList (maybe [] NE.toList rRuleBySecond) $ \s -> declare "Valid values are 0 to 60." $ s >= 0 && s <= 60,
        decorateList (maybe [] NE.toList rRuleByMinute) $ \m -> declare "Valid values are 0 to 59." $ m >= 0 && m <= 59,
        decorateList (maybe [] NE.toList rRuleByHour) $ \m -> declare "Valid values are 0 to 23." $ m >= 0 && m <= 23,
        decorateList (maybe [] NE.toList rRuleByDay) $ \bd ->
          declare "The BYDAY rule part MUST NOT be specified with a numeric value when the FREQ rule part is not set to MONTHLY or YEARLY." $
            let care = case bd of
                  Every _ -> True
                  Specific _ _ -> False
             in case rRuleFrequency of
                  Monthly -> care
                  Yearly -> care
                  _ -> True,
        decorateList
          (maybe [] NE.toList rRuleByMonthDay)
          $ \bmd -> declare "Valid values are 1 to 31 or -31 to -1." $ bmd /= 0 && bmd >= -31 && bmd <= 31,
        declare "The BYMONTHDAY rule part MUST NOT be specified when the FREQ rule part is set to WEEKLY" $
          case rRuleFrequency of
            Weekly -> isNothing rRuleByMonthDay
            _ -> True,
        decorateList
          (maybe [] NE.toList rRuleByYearDay)
          $ \bmd -> declare "Valid values are 1 to 366 or -366 to -1." $ bmd /= 0 && bmd >= -366 && bmd <= 366,
        declare "The BYYEARDAY rule part MUST NOT be specified when the FREQ rule part is set to DAILY, WEEKLY, or MONTHLY." $ case rRuleFrequency of
          Daily -> isNothing rRuleByYearDay
          Weekly -> isNothing rRuleByYearDay
          Monthly -> isNothing rRuleByYearDay
          _ -> True
      ]

data Frequency
  = Secondly
  | Minutely
  | Hourly
  | Daily
  | Weekly
  | Monthly
  | Yearly
  deriving (Show, Eq, Generic)

instance Validity Frequency

data UntilCount
  = -- | The UNTIL rule part defines a DATE or DATE-TIME value that bounds the recurrence rule in an inclusive manner.
    --
    -- If the value specified by UNTIL is synchronized with the specified
    -- recurrence, this DATE or DATE-TIME becomes the last instance of the
    -- recurrence.  The value of the UNTIL rule part MUST have the same value
    -- type as the "DTSTART" property.  Furthermore, if the "DTSTART" property
    -- is specified as a date with local time, then the UNTIL rule part MUST
    -- also be specified as a date with local time.  If the "DTSTART" property
    -- is specified as a date with UTC time or a date with local time and time
    -- zone reference, then the UNTIL rule part MUST be specified as a date
    -- with UTC time.  In the case of the "STANDARD" and "DAYLIGHT"
    -- sub-components the UNTIL rule part MUST always be specified as a date
    -- with UTC time.  If specified as a DATE-TIME value, then it MUST be
    -- specified in a UTC time format.
    Until CalTimestamp
  | -- | The COUNT rule part defines the number of occurrences at which to range-bound the recurrence.
    --
    -- The "DTSTART" property value always counts as the first occurrence.
    Count Word
  | -- | If [the UNTIL rule part is] not present, and the COUNT rule part is also not present, the "RRULE" is considered to repeat forever.
    Indefinitely
  deriving (Show, Eq, Generic)

instance Validity UntilCount

-- | The BYDAY rule part specifies a COMMA-separated list of days of the week;
--
-- Each BYDAY value can also be preceded by a positive (+n) or
-- negative (-n) integer.  If present, this indicates the nth
-- occurrence of a specific day within the MONTHLY or YEARLY "RRULE".
--
-- For example, within a MONTHLY rule, +1MO (or simply 1MO)
-- represents the first Monday within the month, whereas -1MO
-- represents the last Monday of the month.  The numeric value in a
-- BYDAY rule part with the FREQ rule part set to YEARLY corresponds
-- to an offset within the month when the BYMONTH rule part is
-- present, and corresponds to an offset within the year when the
-- BYWEEKNO or BYMONTH rule parts are present.  If an integer
-- modifier is not present, it means all days of this type within the
-- specified frequency.  For example, within a MONTHLY rule, MO
-- represents all Mondays within the month.
data ByDay
  = Every DayOfWeek
  | Specific Int DayOfWeek
  deriving (Show, Eq, Generic)

instance Validity ByDay where
  validate bd =
    mconcat
      [ genericValidate bd,
        case bd of
          Every _ -> valid
          Specific i _ -> declare "The specific weekday number is not zero" $ i /= 0
      ]

deriving instance Generic DayOfWeek

instance Validity DayOfWeek where -- Until we have it in validity-time
  validate = trivialValidation

rruleOccurrencesUntil :: CalDateTime -> RRule -> CalDateTime
rruleOccurrencesUntil = undefined

rruleOccurrences :: CalDateTime -> RRule -> RRuleResult
rruleOccurrences = undefined

data RRuleResult
  = FiniteRecurrences [CalDateTime]
  | InfiniteOccurrences

rruleNextOccurrence :: CalDateTime -> RRule -> Maybe CalDateTime
rruleNextOccurrence = undefined
