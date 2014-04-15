"""
 Copyright (C) 2011, Enthought Inc
 Copyright (C) 2011, Patrick Henaff

 This program is distributed in the hope that it will be useful, but WITHOUT
 ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 FOR A PARTICULAR PURPOSE.  See the license for more details.
"""

include '../../types.pxi'

from cython.operator cimport dereference as deref

from quantlib cimport ql
from quantlib.ql cimport shared_ptr, Handle

from quantlib.quotes cimport Quote
from quantlib.time.calendar cimport Calendar
from quantlib.time.daycounter cimport DayCounter
from quantlib.time.date cimport Period, Date
from quantlib.indexes.ibor_index cimport IborIndex
from quantlib.indexes.swap_index cimport SwapIndex

from quantlib.time.calendar import ModifiedFollowing

cdef class RateHelper:

    def __cinit__(self):
        self._thisptr = NULL

    def __dealloc__(self):
        if self._thisptr is not NULL:
            del self._thisptr
            self._thisptr = NULL

    property quote:
        def __get__(self):
            cdef Handle[ql.Quote] quote_handle = self._thisptr.get().quote()
            cdef shared_ptr[ql.Quote] quote_ptr = shared_ptr[ql.Quote](quote_handle.currentLink())
            value = quote_ptr.get().value()
            return value

    property implied_quote:
        def __get__(self):
            return self._thisptr.get().impliedQuote()


cdef class RelativeDateRateHelper:

    def __cinit__(self):
        self._thisptr = NULL

    def __dealloc__(self):
        if self._thisptr is not NULL:
            del self._thisptr
            self._thisptr = NULL

    property quote:
        def __get__(self):
            cdef Handle[ql.Quote] quote_handle = self._thisptr.get().quote()
            cdef shared_ptr[ql.Quote] quote_ptr = shared_ptr[ql.Quote](quote_handle.currentLink())
            value = quote_ptr.get().value()
            return value

    property implied_quote:
        def __get__(self):
            return self._thisptr.get().impliedQuote()


cdef class DepositRateHelper(RateHelper):
    """Rate helper for bootstrapping over deposit rates. """

    def __init__(self, Rate quote, Period tenor=None, Natural fixing_days=0,
        Calendar calendar=None, int convention=ModifiedFollowing,
        end_of_month=True, DayCounter deposit_day_counter=None,
        IborIndex index=None
    ):

        if index is not None:
            self._thisptr = new shared_ptr[ql.RateHelper](
                new ql.DepositRateHelper(
                    quote,
                    deref(<shared_ptr[ql.IborIndex]*> index._thisptr)
                )
            )
        else:
            self._thisptr = new shared_ptr[ql.RateHelper](
                new ql.DepositRateHelper(
                    quote,
                    deref(tenor._thisptr.get()),
                    <int>fixing_days,
                    deref(calendar._thisptr),
                    <ql.BusinessDayConvention>convention,
                    True,
                    deref(deposit_day_counter._thisptr)
                )
            )

cdef class SwapRateHelper(RelativeDateRateHelper):

    def __init__(self, from_classmethod=False):
        # Creating a SwaprRateHelper without using a class method means the
        # shared_ptr won't be initialized properly and break any subsequent calls
        # to the QuantLib internals... To avoid this, we raise a ValueError if
        # the user tries to instantiate this class if not setting the
        # from_classmethod. This is an ugly workaround but is ok so far.

        if from_classmethod is False:
            raise ValueError(
                'SwapRateHelpers must be instantiated through the class methods'
                ' from_index or from_tenor'
            )

    cdef set_ptr(self, shared_ptr[ql.RelativeDateRateHelper]* ptr):
        self._thisptr = ptr

    @classmethod
    def from_tenor(cls, double rate, Period tenor, Calendar calendar,
                   ql.Frequency fixedFrequency,
                   ql.BusinessDayConvention fixedConvention,
                   DayCounter fixedDayCount, IborIndex iborIndex,
                   Quote spread=None, Period fwdStart=None):

        cdef Handle[ql.Quote] spread_handle

        cdef SwapRateHelper instance = cls(from_classmethod=True)

        if spread is None:
            instance.set_ptr(new shared_ptr[ql.RelativeDateRateHelper](
                new ql.SwapRateHelper(
                    rate,
                    deref(tenor._thisptr.get()),
                    deref(calendar._thisptr),
                    <ql.Frequency> fixedFrequency,
                    <ql.BusinessDayConvention> fixedConvention,
                    deref(fixedDayCount._thisptr),
                    deref(<shared_ptr[ql.IborIndex]*> iborIndex._thisptr))
                )
            )
        else:
            spread_handle = Handle[ql.Quote](deref(spread._thisptr))

            instance.set_ptr(new shared_ptr[ql.RelativeDateRateHelper](
                new ql.SwapRateHelper(
                    rate,
                    deref(tenor._thisptr.get()),
                    deref(calendar._thisptr),
                    <ql.Frequency> fixedFrequency,
                    <ql.BusinessDayConvention> fixedConvention,
                    deref(fixedDayCount._thisptr),
                    deref(<shared_ptr[ql.IborIndex]*> iborIndex._thisptr),
                    spread_handle,
                    deref(fwdStart._thisptr.get()))
                )
            )

        return instance

    @classmethod
    def from_index(cls, double rate, SwapIndex index):

        cdef Handle[ql.Quote] spread_handle = Handle[ql.Quote](new ql.SimpleQuote(0))
        cdef Period p = Period(2, ql.Days)


        cdef SwapRateHelper instance = cls(from_classmethod=True)

        instance.set_ptr(new shared_ptr[ql.RelativeDateRateHelper](
            new ql.SwapRateHelper(
                rate,
                deref(<shared_ptr[ql.SwapIndex]*>index._thisptr),
                #spread_handle,
                #deref(p._thisptr.get()))
                )
            )
        )

        return instance

cdef class FraRateHelper(RelativeDateRateHelper):
    """ Rate helper for bootstrapping over %FRA rates. """

    def __init__(self, Quote rate, Natural months_to_start,
            Natural months_to_end, Natural fixing_days, Calendar calendar,
            ql.BusinessDayConvention convention, end_of_month,
            DayCounter day_counter):

        cdef Handle[ql.Quote] rate_handle = Handle[ql.Quote](deref(rate._thisptr))

        self._thisptr = new shared_ptr[ql.RelativeDateRateHelper](
            new ql.FraRateHelper(
                rate_handle,
                months_to_start,
                months_to_end,
                fixing_days,
                deref(calendar._thisptr),
                <ql.BusinessDayConvention> convention,
                end_of_month,
                deref(day_counter._thisptr),
            )
        )

cdef class FuturesRateHelper(RateHelper):
    """ Rate helper for bootstrapping over IborIndex futures prices. """

    def __init__(self, Quote rate, Date imm_date,
            Natural length_in_months, Calendar calendar,
            ql.BusinessDayConvention convention, end_of_month,
            DayCounter day_counter):

        cdef Handle[ql.Quote] rate_handle = Handle[ql.Quote](deref(rate._thisptr))

        self._thisptr = new shared_ptr[ql.RateHelper](
            new ql.FuturesRateHelper(
                rate_handle,
                deref(imm_date._thisptr.get()),
                length_in_months,
                deref(calendar._thisptr),
                <ql.BusinessDayConvention> convention,
                end_of_month,
                deref(day_counter._thisptr),
            )
        )

