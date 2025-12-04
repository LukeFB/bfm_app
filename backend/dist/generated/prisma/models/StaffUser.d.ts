import type * as runtime from "@prisma/client/runtime/library";
import type * as $Enums from "../enums";
import type * as Prisma from "../internal/prismaNamespace";
/**
 * Model StaffUser
 *
 */
export type StaffUserModel = runtime.Types.Result.DefaultSelection<Prisma.$StaffUserPayload>;
export type AggregateStaffUser = {
    _count: StaffUserCountAggregateOutputType | null;
    _avg: StaffUserAvgAggregateOutputType | null;
    _sum: StaffUserSumAggregateOutputType | null;
    _min: StaffUserMinAggregateOutputType | null;
    _max: StaffUserMaxAggregateOutputType | null;
};
export type StaffUserAvgAggregateOutputType = {
    id: number | null;
};
export type StaffUserSumAggregateOutputType = {
    id: number | null;
};
export type StaffUserMinAggregateOutputType = {
    id: number | null;
    email: string | null;
    passwordHash: string | null;
    role: $Enums.StaffRole | null;
    createdAt: Date | null;
    updatedAt: Date | null;
};
export type StaffUserMaxAggregateOutputType = {
    id: number | null;
    email: string | null;
    passwordHash: string | null;
    role: $Enums.StaffRole | null;
    createdAt: Date | null;
    updatedAt: Date | null;
};
export type StaffUserCountAggregateOutputType = {
    id: number;
    email: number;
    passwordHash: number;
    role: number;
    createdAt: number;
    updatedAt: number;
    _all: number;
};
export type StaffUserAvgAggregateInputType = {
    id?: true;
};
export type StaffUserSumAggregateInputType = {
    id?: true;
};
export type StaffUserMinAggregateInputType = {
    id?: true;
    email?: true;
    passwordHash?: true;
    role?: true;
    createdAt?: true;
    updatedAt?: true;
};
export type StaffUserMaxAggregateInputType = {
    id?: true;
    email?: true;
    passwordHash?: true;
    role?: true;
    createdAt?: true;
    updatedAt?: true;
};
export type StaffUserCountAggregateInputType = {
    id?: true;
    email?: true;
    passwordHash?: true;
    role?: true;
    createdAt?: true;
    updatedAt?: true;
    _all?: true;
};
export type StaffUserAggregateArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    /**
     * Filter which StaffUser to aggregate.
     */
    where?: Prisma.StaffUserWhereInput;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/sorting Sorting Docs}
     *
     * Determine the order of StaffUsers to fetch.
     */
    orderBy?: Prisma.StaffUserOrderByWithRelationInput | Prisma.StaffUserOrderByWithRelationInput[];
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/pagination#cursor-based-pagination Cursor Docs}
     *
     * Sets the start position
     */
    cursor?: Prisma.StaffUserWhereUniqueInput;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/pagination Pagination Docs}
     *
     * Take `±n` StaffUsers from the position of the cursor.
     */
    take?: number;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/pagination Pagination Docs}
     *
     * Skip the first `n` StaffUsers.
     */
    skip?: number;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/aggregations Aggregation Docs}
     *
     * Count returned StaffUsers
    **/
    _count?: true | StaffUserCountAggregateInputType;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/aggregations Aggregation Docs}
     *
     * Select which fields to average
    **/
    _avg?: StaffUserAvgAggregateInputType;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/aggregations Aggregation Docs}
     *
     * Select which fields to sum
    **/
    _sum?: StaffUserSumAggregateInputType;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/aggregations Aggregation Docs}
     *
     * Select which fields to find the minimum value
    **/
    _min?: StaffUserMinAggregateInputType;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/aggregations Aggregation Docs}
     *
     * Select which fields to find the maximum value
    **/
    _max?: StaffUserMaxAggregateInputType;
};
export type GetStaffUserAggregateType<T extends StaffUserAggregateArgs> = {
    [P in keyof T & keyof AggregateStaffUser]: P extends '_count' | 'count' ? T[P] extends true ? number : Prisma.GetScalarType<T[P], AggregateStaffUser[P]> : Prisma.GetScalarType<T[P], AggregateStaffUser[P]>;
};
export type StaffUserGroupByArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    where?: Prisma.StaffUserWhereInput;
    orderBy?: Prisma.StaffUserOrderByWithAggregationInput | Prisma.StaffUserOrderByWithAggregationInput[];
    by: Prisma.StaffUserScalarFieldEnum[] | Prisma.StaffUserScalarFieldEnum;
    having?: Prisma.StaffUserScalarWhereWithAggregatesInput;
    take?: number;
    skip?: number;
    _count?: StaffUserCountAggregateInputType | true;
    _avg?: StaffUserAvgAggregateInputType;
    _sum?: StaffUserSumAggregateInputType;
    _min?: StaffUserMinAggregateInputType;
    _max?: StaffUserMaxAggregateInputType;
};
export type StaffUserGroupByOutputType = {
    id: number;
    email: string;
    passwordHash: string;
    role: $Enums.StaffRole;
    createdAt: Date;
    updatedAt: Date;
    _count: StaffUserCountAggregateOutputType | null;
    _avg: StaffUserAvgAggregateOutputType | null;
    _sum: StaffUserSumAggregateOutputType | null;
    _min: StaffUserMinAggregateOutputType | null;
    _max: StaffUserMaxAggregateOutputType | null;
};
type GetStaffUserGroupByPayload<T extends StaffUserGroupByArgs> = Prisma.PrismaPromise<Array<Prisma.PickEnumerable<StaffUserGroupByOutputType, T['by']> & {
    [P in ((keyof T) & (keyof StaffUserGroupByOutputType))]: P extends '_count' ? T[P] extends boolean ? number : Prisma.GetScalarType<T[P], StaffUserGroupByOutputType[P]> : Prisma.GetScalarType<T[P], StaffUserGroupByOutputType[P]>;
}>>;
export type StaffUserWhereInput = {
    AND?: Prisma.StaffUserWhereInput | Prisma.StaffUserWhereInput[];
    OR?: Prisma.StaffUserWhereInput[];
    NOT?: Prisma.StaffUserWhereInput | Prisma.StaffUserWhereInput[];
    id?: Prisma.IntFilter<"StaffUser"> | number;
    email?: Prisma.StringFilter<"StaffUser"> | string;
    passwordHash?: Prisma.StringFilter<"StaffUser"> | string;
    role?: Prisma.EnumStaffRoleFilter<"StaffUser"> | $Enums.StaffRole;
    createdAt?: Prisma.DateTimeFilter<"StaffUser"> | Date | string;
    updatedAt?: Prisma.DateTimeFilter<"StaffUser"> | Date | string;
    referrals?: Prisma.ReferralListRelationFilter;
    tips?: Prisma.TipListRelationFilter;
    events?: Prisma.EventListRelationFilter;
};
export type StaffUserOrderByWithRelationInput = {
    id?: Prisma.SortOrder;
    email?: Prisma.SortOrder;
    passwordHash?: Prisma.SortOrder;
    role?: Prisma.SortOrder;
    createdAt?: Prisma.SortOrder;
    updatedAt?: Prisma.SortOrder;
    referrals?: Prisma.ReferralOrderByRelationAggregateInput;
    tips?: Prisma.TipOrderByRelationAggregateInput;
    events?: Prisma.EventOrderByRelationAggregateInput;
};
export type StaffUserWhereUniqueInput = Prisma.AtLeast<{
    id?: number;
    email?: string;
    AND?: Prisma.StaffUserWhereInput | Prisma.StaffUserWhereInput[];
    OR?: Prisma.StaffUserWhereInput[];
    NOT?: Prisma.StaffUserWhereInput | Prisma.StaffUserWhereInput[];
    passwordHash?: Prisma.StringFilter<"StaffUser"> | string;
    role?: Prisma.EnumStaffRoleFilter<"StaffUser"> | $Enums.StaffRole;
    createdAt?: Prisma.DateTimeFilter<"StaffUser"> | Date | string;
    updatedAt?: Prisma.DateTimeFilter<"StaffUser"> | Date | string;
    referrals?: Prisma.ReferralListRelationFilter;
    tips?: Prisma.TipListRelationFilter;
    events?: Prisma.EventListRelationFilter;
}, "id" | "email">;
export type StaffUserOrderByWithAggregationInput = {
    id?: Prisma.SortOrder;
    email?: Prisma.SortOrder;
    passwordHash?: Prisma.SortOrder;
    role?: Prisma.SortOrder;
    createdAt?: Prisma.SortOrder;
    updatedAt?: Prisma.SortOrder;
    _count?: Prisma.StaffUserCountOrderByAggregateInput;
    _avg?: Prisma.StaffUserAvgOrderByAggregateInput;
    _max?: Prisma.StaffUserMaxOrderByAggregateInput;
    _min?: Prisma.StaffUserMinOrderByAggregateInput;
    _sum?: Prisma.StaffUserSumOrderByAggregateInput;
};
export type StaffUserScalarWhereWithAggregatesInput = {
    AND?: Prisma.StaffUserScalarWhereWithAggregatesInput | Prisma.StaffUserScalarWhereWithAggregatesInput[];
    OR?: Prisma.StaffUserScalarWhereWithAggregatesInput[];
    NOT?: Prisma.StaffUserScalarWhereWithAggregatesInput | Prisma.StaffUserScalarWhereWithAggregatesInput[];
    id?: Prisma.IntWithAggregatesFilter<"StaffUser"> | number;
    email?: Prisma.StringWithAggregatesFilter<"StaffUser"> | string;
    passwordHash?: Prisma.StringWithAggregatesFilter<"StaffUser"> | string;
    role?: Prisma.EnumStaffRoleWithAggregatesFilter<"StaffUser"> | $Enums.StaffRole;
    createdAt?: Prisma.DateTimeWithAggregatesFilter<"StaffUser"> | Date | string;
    updatedAt?: Prisma.DateTimeWithAggregatesFilter<"StaffUser"> | Date | string;
};
export type StaffUserCreateInput = {
    email: string;
    passwordHash: string;
    role?: $Enums.StaffRole;
    createdAt?: Date | string;
    updatedAt?: Date | string;
    referrals?: Prisma.ReferralCreateNestedManyWithoutCreatedByInput;
    tips?: Prisma.TipCreateNestedManyWithoutCreatedByInput;
    events?: Prisma.EventCreateNestedManyWithoutCreatedByInput;
};
export type StaffUserUncheckedCreateInput = {
    id?: number;
    email: string;
    passwordHash: string;
    role?: $Enums.StaffRole;
    createdAt?: Date | string;
    updatedAt?: Date | string;
    referrals?: Prisma.ReferralUncheckedCreateNestedManyWithoutCreatedByInput;
    tips?: Prisma.TipUncheckedCreateNestedManyWithoutCreatedByInput;
    events?: Prisma.EventUncheckedCreateNestedManyWithoutCreatedByInput;
};
export type StaffUserUpdateInput = {
    email?: Prisma.StringFieldUpdateOperationsInput | string;
    passwordHash?: Prisma.StringFieldUpdateOperationsInput | string;
    role?: Prisma.EnumStaffRoleFieldUpdateOperationsInput | $Enums.StaffRole;
    createdAt?: Prisma.DateTimeFieldUpdateOperationsInput | Date | string;
    updatedAt?: Prisma.DateTimeFieldUpdateOperationsInput | Date | string;
    referrals?: Prisma.ReferralUpdateManyWithoutCreatedByNestedInput;
    tips?: Prisma.TipUpdateManyWithoutCreatedByNestedInput;
    events?: Prisma.EventUpdateManyWithoutCreatedByNestedInput;
};
export type StaffUserUncheckedUpdateInput = {
    id?: Prisma.IntFieldUpdateOperationsInput | number;
    email?: Prisma.StringFieldUpdateOperationsInput | string;
    passwordHash?: Prisma.StringFieldUpdateOperationsInput | string;
    role?: Prisma.EnumStaffRoleFieldUpdateOperationsInput | $Enums.StaffRole;
    createdAt?: Prisma.DateTimeFieldUpdateOperationsInput | Date | string;
    updatedAt?: Prisma.DateTimeFieldUpdateOperationsInput | Date | string;
    referrals?: Prisma.ReferralUncheckedUpdateManyWithoutCreatedByNestedInput;
    tips?: Prisma.TipUncheckedUpdateManyWithoutCreatedByNestedInput;
    events?: Prisma.EventUncheckedUpdateManyWithoutCreatedByNestedInput;
};
export type StaffUserCreateManyInput = {
    id?: number;
    email: string;
    passwordHash: string;
    role?: $Enums.StaffRole;
    createdAt?: Date | string;
    updatedAt?: Date | string;
};
export type StaffUserUpdateManyMutationInput = {
    email?: Prisma.StringFieldUpdateOperationsInput | string;
    passwordHash?: Prisma.StringFieldUpdateOperationsInput | string;
    role?: Prisma.EnumStaffRoleFieldUpdateOperationsInput | $Enums.StaffRole;
    createdAt?: Prisma.DateTimeFieldUpdateOperationsInput | Date | string;
    updatedAt?: Prisma.DateTimeFieldUpdateOperationsInput | Date | string;
};
export type StaffUserUncheckedUpdateManyInput = {
    id?: Prisma.IntFieldUpdateOperationsInput | number;
    email?: Prisma.StringFieldUpdateOperationsInput | string;
    passwordHash?: Prisma.StringFieldUpdateOperationsInput | string;
    role?: Prisma.EnumStaffRoleFieldUpdateOperationsInput | $Enums.StaffRole;
    createdAt?: Prisma.DateTimeFieldUpdateOperationsInput | Date | string;
    updatedAt?: Prisma.DateTimeFieldUpdateOperationsInput | Date | string;
};
export type StaffUserCountOrderByAggregateInput = {
    id?: Prisma.SortOrder;
    email?: Prisma.SortOrder;
    passwordHash?: Prisma.SortOrder;
    role?: Prisma.SortOrder;
    createdAt?: Prisma.SortOrder;
    updatedAt?: Prisma.SortOrder;
};
export type StaffUserAvgOrderByAggregateInput = {
    id?: Prisma.SortOrder;
};
export type StaffUserMaxOrderByAggregateInput = {
    id?: Prisma.SortOrder;
    email?: Prisma.SortOrder;
    passwordHash?: Prisma.SortOrder;
    role?: Prisma.SortOrder;
    createdAt?: Prisma.SortOrder;
    updatedAt?: Prisma.SortOrder;
};
export type StaffUserMinOrderByAggregateInput = {
    id?: Prisma.SortOrder;
    email?: Prisma.SortOrder;
    passwordHash?: Prisma.SortOrder;
    role?: Prisma.SortOrder;
    createdAt?: Prisma.SortOrder;
    updatedAt?: Prisma.SortOrder;
};
export type StaffUserSumOrderByAggregateInput = {
    id?: Prisma.SortOrder;
};
export type StaffUserNullableScalarRelationFilter = {
    is?: Prisma.StaffUserWhereInput | null;
    isNot?: Prisma.StaffUserWhereInput | null;
};
export type StringFieldUpdateOperationsInput = {
    set?: string;
};
export type EnumStaffRoleFieldUpdateOperationsInput = {
    set?: $Enums.StaffRole;
};
export type DateTimeFieldUpdateOperationsInput = {
    set?: Date | string;
};
export type IntFieldUpdateOperationsInput = {
    set?: number;
    increment?: number;
    decrement?: number;
    multiply?: number;
    divide?: number;
};
export type StaffUserCreateNestedOneWithoutReferralsInput = {
    create?: Prisma.XOR<Prisma.StaffUserCreateWithoutReferralsInput, Prisma.StaffUserUncheckedCreateWithoutReferralsInput>;
    connectOrCreate?: Prisma.StaffUserCreateOrConnectWithoutReferralsInput;
    connect?: Prisma.StaffUserWhereUniqueInput;
};
export type StaffUserUpdateOneWithoutReferralsNestedInput = {
    create?: Prisma.XOR<Prisma.StaffUserCreateWithoutReferralsInput, Prisma.StaffUserUncheckedCreateWithoutReferralsInput>;
    connectOrCreate?: Prisma.StaffUserCreateOrConnectWithoutReferralsInput;
    upsert?: Prisma.StaffUserUpsertWithoutReferralsInput;
    disconnect?: Prisma.StaffUserWhereInput | boolean;
    delete?: Prisma.StaffUserWhereInput | boolean;
    connect?: Prisma.StaffUserWhereUniqueInput;
    update?: Prisma.XOR<Prisma.XOR<Prisma.StaffUserUpdateToOneWithWhereWithoutReferralsInput, Prisma.StaffUserUpdateWithoutReferralsInput>, Prisma.StaffUserUncheckedUpdateWithoutReferralsInput>;
};
export type StaffUserCreateNestedOneWithoutTipsInput = {
    create?: Prisma.XOR<Prisma.StaffUserCreateWithoutTipsInput, Prisma.StaffUserUncheckedCreateWithoutTipsInput>;
    connectOrCreate?: Prisma.StaffUserCreateOrConnectWithoutTipsInput;
    connect?: Prisma.StaffUserWhereUniqueInput;
};
export type StaffUserUpdateOneWithoutTipsNestedInput = {
    create?: Prisma.XOR<Prisma.StaffUserCreateWithoutTipsInput, Prisma.StaffUserUncheckedCreateWithoutTipsInput>;
    connectOrCreate?: Prisma.StaffUserCreateOrConnectWithoutTipsInput;
    upsert?: Prisma.StaffUserUpsertWithoutTipsInput;
    disconnect?: Prisma.StaffUserWhereInput | boolean;
    delete?: Prisma.StaffUserWhereInput | boolean;
    connect?: Prisma.StaffUserWhereUniqueInput;
    update?: Prisma.XOR<Prisma.XOR<Prisma.StaffUserUpdateToOneWithWhereWithoutTipsInput, Prisma.StaffUserUpdateWithoutTipsInput>, Prisma.StaffUserUncheckedUpdateWithoutTipsInput>;
};
export type StaffUserCreateNestedOneWithoutEventsInput = {
    create?: Prisma.XOR<Prisma.StaffUserCreateWithoutEventsInput, Prisma.StaffUserUncheckedCreateWithoutEventsInput>;
    connectOrCreate?: Prisma.StaffUserCreateOrConnectWithoutEventsInput;
    connect?: Prisma.StaffUserWhereUniqueInput;
};
export type StaffUserUpdateOneWithoutEventsNestedInput = {
    create?: Prisma.XOR<Prisma.StaffUserCreateWithoutEventsInput, Prisma.StaffUserUncheckedCreateWithoutEventsInput>;
    connectOrCreate?: Prisma.StaffUserCreateOrConnectWithoutEventsInput;
    upsert?: Prisma.StaffUserUpsertWithoutEventsInput;
    disconnect?: Prisma.StaffUserWhereInput | boolean;
    delete?: Prisma.StaffUserWhereInput | boolean;
    connect?: Prisma.StaffUserWhereUniqueInput;
    update?: Prisma.XOR<Prisma.XOR<Prisma.StaffUserUpdateToOneWithWhereWithoutEventsInput, Prisma.StaffUserUpdateWithoutEventsInput>, Prisma.StaffUserUncheckedUpdateWithoutEventsInput>;
};
export type StaffUserCreateWithoutReferralsInput = {
    email: string;
    passwordHash: string;
    role?: $Enums.StaffRole;
    createdAt?: Date | string;
    updatedAt?: Date | string;
    tips?: Prisma.TipCreateNestedManyWithoutCreatedByInput;
    events?: Prisma.EventCreateNestedManyWithoutCreatedByInput;
};
export type StaffUserUncheckedCreateWithoutReferralsInput = {
    id?: number;
    email: string;
    passwordHash: string;
    role?: $Enums.StaffRole;
    createdAt?: Date | string;
    updatedAt?: Date | string;
    tips?: Prisma.TipUncheckedCreateNestedManyWithoutCreatedByInput;
    events?: Prisma.EventUncheckedCreateNestedManyWithoutCreatedByInput;
};
export type StaffUserCreateOrConnectWithoutReferralsInput = {
    where: Prisma.StaffUserWhereUniqueInput;
    create: Prisma.XOR<Prisma.StaffUserCreateWithoutReferralsInput, Prisma.StaffUserUncheckedCreateWithoutReferralsInput>;
};
export type StaffUserUpsertWithoutReferralsInput = {
    update: Prisma.XOR<Prisma.StaffUserUpdateWithoutReferralsInput, Prisma.StaffUserUncheckedUpdateWithoutReferralsInput>;
    create: Prisma.XOR<Prisma.StaffUserCreateWithoutReferralsInput, Prisma.StaffUserUncheckedCreateWithoutReferralsInput>;
    where?: Prisma.StaffUserWhereInput;
};
export type StaffUserUpdateToOneWithWhereWithoutReferralsInput = {
    where?: Prisma.StaffUserWhereInput;
    data: Prisma.XOR<Prisma.StaffUserUpdateWithoutReferralsInput, Prisma.StaffUserUncheckedUpdateWithoutReferralsInput>;
};
export type StaffUserUpdateWithoutReferralsInput = {
    email?: Prisma.StringFieldUpdateOperationsInput | string;
    passwordHash?: Prisma.StringFieldUpdateOperationsInput | string;
    role?: Prisma.EnumStaffRoleFieldUpdateOperationsInput | $Enums.StaffRole;
    createdAt?: Prisma.DateTimeFieldUpdateOperationsInput | Date | string;
    updatedAt?: Prisma.DateTimeFieldUpdateOperationsInput | Date | string;
    tips?: Prisma.TipUpdateManyWithoutCreatedByNestedInput;
    events?: Prisma.EventUpdateManyWithoutCreatedByNestedInput;
};
export type StaffUserUncheckedUpdateWithoutReferralsInput = {
    id?: Prisma.IntFieldUpdateOperationsInput | number;
    email?: Prisma.StringFieldUpdateOperationsInput | string;
    passwordHash?: Prisma.StringFieldUpdateOperationsInput | string;
    role?: Prisma.EnumStaffRoleFieldUpdateOperationsInput | $Enums.StaffRole;
    createdAt?: Prisma.DateTimeFieldUpdateOperationsInput | Date | string;
    updatedAt?: Prisma.DateTimeFieldUpdateOperationsInput | Date | string;
    tips?: Prisma.TipUncheckedUpdateManyWithoutCreatedByNestedInput;
    events?: Prisma.EventUncheckedUpdateManyWithoutCreatedByNestedInput;
};
export type StaffUserCreateWithoutTipsInput = {
    email: string;
    passwordHash: string;
    role?: $Enums.StaffRole;
    createdAt?: Date | string;
    updatedAt?: Date | string;
    referrals?: Prisma.ReferralCreateNestedManyWithoutCreatedByInput;
    events?: Prisma.EventCreateNestedManyWithoutCreatedByInput;
};
export type StaffUserUncheckedCreateWithoutTipsInput = {
    id?: number;
    email: string;
    passwordHash: string;
    role?: $Enums.StaffRole;
    createdAt?: Date | string;
    updatedAt?: Date | string;
    referrals?: Prisma.ReferralUncheckedCreateNestedManyWithoutCreatedByInput;
    events?: Prisma.EventUncheckedCreateNestedManyWithoutCreatedByInput;
};
export type StaffUserCreateOrConnectWithoutTipsInput = {
    where: Prisma.StaffUserWhereUniqueInput;
    create: Prisma.XOR<Prisma.StaffUserCreateWithoutTipsInput, Prisma.StaffUserUncheckedCreateWithoutTipsInput>;
};
export type StaffUserUpsertWithoutTipsInput = {
    update: Prisma.XOR<Prisma.StaffUserUpdateWithoutTipsInput, Prisma.StaffUserUncheckedUpdateWithoutTipsInput>;
    create: Prisma.XOR<Prisma.StaffUserCreateWithoutTipsInput, Prisma.StaffUserUncheckedCreateWithoutTipsInput>;
    where?: Prisma.StaffUserWhereInput;
};
export type StaffUserUpdateToOneWithWhereWithoutTipsInput = {
    where?: Prisma.StaffUserWhereInput;
    data: Prisma.XOR<Prisma.StaffUserUpdateWithoutTipsInput, Prisma.StaffUserUncheckedUpdateWithoutTipsInput>;
};
export type StaffUserUpdateWithoutTipsInput = {
    email?: Prisma.StringFieldUpdateOperationsInput | string;
    passwordHash?: Prisma.StringFieldUpdateOperationsInput | string;
    role?: Prisma.EnumStaffRoleFieldUpdateOperationsInput | $Enums.StaffRole;
    createdAt?: Prisma.DateTimeFieldUpdateOperationsInput | Date | string;
    updatedAt?: Prisma.DateTimeFieldUpdateOperationsInput | Date | string;
    referrals?: Prisma.ReferralUpdateManyWithoutCreatedByNestedInput;
    events?: Prisma.EventUpdateManyWithoutCreatedByNestedInput;
};
export type StaffUserUncheckedUpdateWithoutTipsInput = {
    id?: Prisma.IntFieldUpdateOperationsInput | number;
    email?: Prisma.StringFieldUpdateOperationsInput | string;
    passwordHash?: Prisma.StringFieldUpdateOperationsInput | string;
    role?: Prisma.EnumStaffRoleFieldUpdateOperationsInput | $Enums.StaffRole;
    createdAt?: Prisma.DateTimeFieldUpdateOperationsInput | Date | string;
    updatedAt?: Prisma.DateTimeFieldUpdateOperationsInput | Date | string;
    referrals?: Prisma.ReferralUncheckedUpdateManyWithoutCreatedByNestedInput;
    events?: Prisma.EventUncheckedUpdateManyWithoutCreatedByNestedInput;
};
export type StaffUserCreateWithoutEventsInput = {
    email: string;
    passwordHash: string;
    role?: $Enums.StaffRole;
    createdAt?: Date | string;
    updatedAt?: Date | string;
    referrals?: Prisma.ReferralCreateNestedManyWithoutCreatedByInput;
    tips?: Prisma.TipCreateNestedManyWithoutCreatedByInput;
};
export type StaffUserUncheckedCreateWithoutEventsInput = {
    id?: number;
    email: string;
    passwordHash: string;
    role?: $Enums.StaffRole;
    createdAt?: Date | string;
    updatedAt?: Date | string;
    referrals?: Prisma.ReferralUncheckedCreateNestedManyWithoutCreatedByInput;
    tips?: Prisma.TipUncheckedCreateNestedManyWithoutCreatedByInput;
};
export type StaffUserCreateOrConnectWithoutEventsInput = {
    where: Prisma.StaffUserWhereUniqueInput;
    create: Prisma.XOR<Prisma.StaffUserCreateWithoutEventsInput, Prisma.StaffUserUncheckedCreateWithoutEventsInput>;
};
export type StaffUserUpsertWithoutEventsInput = {
    update: Prisma.XOR<Prisma.StaffUserUpdateWithoutEventsInput, Prisma.StaffUserUncheckedUpdateWithoutEventsInput>;
    create: Prisma.XOR<Prisma.StaffUserCreateWithoutEventsInput, Prisma.StaffUserUncheckedCreateWithoutEventsInput>;
    where?: Prisma.StaffUserWhereInput;
};
export type StaffUserUpdateToOneWithWhereWithoutEventsInput = {
    where?: Prisma.StaffUserWhereInput;
    data: Prisma.XOR<Prisma.StaffUserUpdateWithoutEventsInput, Prisma.StaffUserUncheckedUpdateWithoutEventsInput>;
};
export type StaffUserUpdateWithoutEventsInput = {
    email?: Prisma.StringFieldUpdateOperationsInput | string;
    passwordHash?: Prisma.StringFieldUpdateOperationsInput | string;
    role?: Prisma.EnumStaffRoleFieldUpdateOperationsInput | $Enums.StaffRole;
    createdAt?: Prisma.DateTimeFieldUpdateOperationsInput | Date | string;
    updatedAt?: Prisma.DateTimeFieldUpdateOperationsInput | Date | string;
    referrals?: Prisma.ReferralUpdateManyWithoutCreatedByNestedInput;
    tips?: Prisma.TipUpdateManyWithoutCreatedByNestedInput;
};
export type StaffUserUncheckedUpdateWithoutEventsInput = {
    id?: Prisma.IntFieldUpdateOperationsInput | number;
    email?: Prisma.StringFieldUpdateOperationsInput | string;
    passwordHash?: Prisma.StringFieldUpdateOperationsInput | string;
    role?: Prisma.EnumStaffRoleFieldUpdateOperationsInput | $Enums.StaffRole;
    createdAt?: Prisma.DateTimeFieldUpdateOperationsInput | Date | string;
    updatedAt?: Prisma.DateTimeFieldUpdateOperationsInput | Date | string;
    referrals?: Prisma.ReferralUncheckedUpdateManyWithoutCreatedByNestedInput;
    tips?: Prisma.TipUncheckedUpdateManyWithoutCreatedByNestedInput;
};
/**
 * Count Type StaffUserCountOutputType
 */
export type StaffUserCountOutputType = {
    referrals: number;
    tips: number;
    events: number;
};
export type StaffUserCountOutputTypeSelect<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    referrals?: boolean | StaffUserCountOutputTypeCountReferralsArgs;
    tips?: boolean | StaffUserCountOutputTypeCountTipsArgs;
    events?: boolean | StaffUserCountOutputTypeCountEventsArgs;
};
/**
 * StaffUserCountOutputType without action
 */
export type StaffUserCountOutputTypeDefaultArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    /**
     * Select specific fields to fetch from the StaffUserCountOutputType
     */
    select?: Prisma.StaffUserCountOutputTypeSelect<ExtArgs> | null;
};
/**
 * StaffUserCountOutputType without action
 */
export type StaffUserCountOutputTypeCountReferralsArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    where?: Prisma.ReferralWhereInput;
};
/**
 * StaffUserCountOutputType without action
 */
export type StaffUserCountOutputTypeCountTipsArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    where?: Prisma.TipWhereInput;
};
/**
 * StaffUserCountOutputType without action
 */
export type StaffUserCountOutputTypeCountEventsArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    where?: Prisma.EventWhereInput;
};
export type StaffUserSelect<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = runtime.Types.Extensions.GetSelect<{
    id?: boolean;
    email?: boolean;
    passwordHash?: boolean;
    role?: boolean;
    createdAt?: boolean;
    updatedAt?: boolean;
    referrals?: boolean | Prisma.StaffUser$referralsArgs<ExtArgs>;
    tips?: boolean | Prisma.StaffUser$tipsArgs<ExtArgs>;
    events?: boolean | Prisma.StaffUser$eventsArgs<ExtArgs>;
    _count?: boolean | Prisma.StaffUserCountOutputTypeDefaultArgs<ExtArgs>;
}, ExtArgs["result"]["staffUser"]>;
export type StaffUserSelectCreateManyAndReturn<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = runtime.Types.Extensions.GetSelect<{
    id?: boolean;
    email?: boolean;
    passwordHash?: boolean;
    role?: boolean;
    createdAt?: boolean;
    updatedAt?: boolean;
}, ExtArgs["result"]["staffUser"]>;
export type StaffUserSelectUpdateManyAndReturn<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = runtime.Types.Extensions.GetSelect<{
    id?: boolean;
    email?: boolean;
    passwordHash?: boolean;
    role?: boolean;
    createdAt?: boolean;
    updatedAt?: boolean;
}, ExtArgs["result"]["staffUser"]>;
export type StaffUserSelectScalar = {
    id?: boolean;
    email?: boolean;
    passwordHash?: boolean;
    role?: boolean;
    createdAt?: boolean;
    updatedAt?: boolean;
};
export type StaffUserOmit<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = runtime.Types.Extensions.GetOmit<"id" | "email" | "passwordHash" | "role" | "createdAt" | "updatedAt", ExtArgs["result"]["staffUser"]>;
export type StaffUserInclude<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    referrals?: boolean | Prisma.StaffUser$referralsArgs<ExtArgs>;
    tips?: boolean | Prisma.StaffUser$tipsArgs<ExtArgs>;
    events?: boolean | Prisma.StaffUser$eventsArgs<ExtArgs>;
    _count?: boolean | Prisma.StaffUserCountOutputTypeDefaultArgs<ExtArgs>;
};
export type StaffUserIncludeCreateManyAndReturn<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {};
export type StaffUserIncludeUpdateManyAndReturn<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {};
export type $StaffUserPayload<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    name: "StaffUser";
    objects: {
        referrals: Prisma.$ReferralPayload<ExtArgs>[];
        tips: Prisma.$TipPayload<ExtArgs>[];
        events: Prisma.$EventPayload<ExtArgs>[];
    };
    scalars: runtime.Types.Extensions.GetPayloadResult<{
        id: number;
        email: string;
        passwordHash: string;
        role: $Enums.StaffRole;
        createdAt: Date;
        updatedAt: Date;
    }, ExtArgs["result"]["staffUser"]>;
    composites: {};
};
export type StaffUserGetPayload<S extends boolean | null | undefined | StaffUserDefaultArgs> = runtime.Types.Result.GetResult<Prisma.$StaffUserPayload, S>;
export type StaffUserCountArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = Omit<StaffUserFindManyArgs, 'select' | 'include' | 'distinct' | 'omit'> & {
    select?: StaffUserCountAggregateInputType | true;
};
export interface StaffUserDelegate<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs, GlobalOmitOptions = {}> {
    [K: symbol]: {
        types: Prisma.TypeMap<ExtArgs>['model']['StaffUser'];
        meta: {
            name: 'StaffUser';
        };
    };
    /**
     * Find zero or one StaffUser that matches the filter.
     * @param {StaffUserFindUniqueArgs} args - Arguments to find a StaffUser
     * @example
     * // Get one StaffUser
     * const staffUser = await prisma.staffUser.findUnique({
     *   where: {
     *     // ... provide filter here
     *   }
     * })
     */
    findUnique<T extends StaffUserFindUniqueArgs>(args: Prisma.SelectSubset<T, StaffUserFindUniqueArgs<ExtArgs>>): Prisma.Prisma__StaffUserClient<runtime.Types.Result.GetResult<Prisma.$StaffUserPayload<ExtArgs>, T, "findUnique", GlobalOmitOptions> | null, null, ExtArgs, GlobalOmitOptions>;
    /**
     * Find one StaffUser that matches the filter or throw an error with `error.code='P2025'`
     * if no matches were found.
     * @param {StaffUserFindUniqueOrThrowArgs} args - Arguments to find a StaffUser
     * @example
     * // Get one StaffUser
     * const staffUser = await prisma.staffUser.findUniqueOrThrow({
     *   where: {
     *     // ... provide filter here
     *   }
     * })
     */
    findUniqueOrThrow<T extends StaffUserFindUniqueOrThrowArgs>(args: Prisma.SelectSubset<T, StaffUserFindUniqueOrThrowArgs<ExtArgs>>): Prisma.Prisma__StaffUserClient<runtime.Types.Result.GetResult<Prisma.$StaffUserPayload<ExtArgs>, T, "findUniqueOrThrow", GlobalOmitOptions>, never, ExtArgs, GlobalOmitOptions>;
    /**
     * Find the first StaffUser that matches the filter.
     * Note, that providing `undefined` is treated as the value not being there.
     * Read more here: https://pris.ly/d/null-undefined
     * @param {StaffUserFindFirstArgs} args - Arguments to find a StaffUser
     * @example
     * // Get one StaffUser
     * const staffUser = await prisma.staffUser.findFirst({
     *   where: {
     *     // ... provide filter here
     *   }
     * })
     */
    findFirst<T extends StaffUserFindFirstArgs>(args?: Prisma.SelectSubset<T, StaffUserFindFirstArgs<ExtArgs>>): Prisma.Prisma__StaffUserClient<runtime.Types.Result.GetResult<Prisma.$StaffUserPayload<ExtArgs>, T, "findFirst", GlobalOmitOptions> | null, null, ExtArgs, GlobalOmitOptions>;
    /**
     * Find the first StaffUser that matches the filter or
     * throw `PrismaKnownClientError` with `P2025` code if no matches were found.
     * Note, that providing `undefined` is treated as the value not being there.
     * Read more here: https://pris.ly/d/null-undefined
     * @param {StaffUserFindFirstOrThrowArgs} args - Arguments to find a StaffUser
     * @example
     * // Get one StaffUser
     * const staffUser = await prisma.staffUser.findFirstOrThrow({
     *   where: {
     *     // ... provide filter here
     *   }
     * })
     */
    findFirstOrThrow<T extends StaffUserFindFirstOrThrowArgs>(args?: Prisma.SelectSubset<T, StaffUserFindFirstOrThrowArgs<ExtArgs>>): Prisma.Prisma__StaffUserClient<runtime.Types.Result.GetResult<Prisma.$StaffUserPayload<ExtArgs>, T, "findFirstOrThrow", GlobalOmitOptions>, never, ExtArgs, GlobalOmitOptions>;
    /**
     * Find zero or more StaffUsers that matches the filter.
     * Note, that providing `undefined` is treated as the value not being there.
     * Read more here: https://pris.ly/d/null-undefined
     * @param {StaffUserFindManyArgs} args - Arguments to filter and select certain fields only.
     * @example
     * // Get all StaffUsers
     * const staffUsers = await prisma.staffUser.findMany()
     *
     * // Get first 10 StaffUsers
     * const staffUsers = await prisma.staffUser.findMany({ take: 10 })
     *
     * // Only select the `id`
     * const staffUserWithIdOnly = await prisma.staffUser.findMany({ select: { id: true } })
     *
     */
    findMany<T extends StaffUserFindManyArgs>(args?: Prisma.SelectSubset<T, StaffUserFindManyArgs<ExtArgs>>): Prisma.PrismaPromise<runtime.Types.Result.GetResult<Prisma.$StaffUserPayload<ExtArgs>, T, "findMany", GlobalOmitOptions>>;
    /**
     * Create a StaffUser.
     * @param {StaffUserCreateArgs} args - Arguments to create a StaffUser.
     * @example
     * // Create one StaffUser
     * const StaffUser = await prisma.staffUser.create({
     *   data: {
     *     // ... data to create a StaffUser
     *   }
     * })
     *
     */
    create<T extends StaffUserCreateArgs>(args: Prisma.SelectSubset<T, StaffUserCreateArgs<ExtArgs>>): Prisma.Prisma__StaffUserClient<runtime.Types.Result.GetResult<Prisma.$StaffUserPayload<ExtArgs>, T, "create", GlobalOmitOptions>, never, ExtArgs, GlobalOmitOptions>;
    /**
     * Create many StaffUsers.
     * @param {StaffUserCreateManyArgs} args - Arguments to create many StaffUsers.
     * @example
     * // Create many StaffUsers
     * const staffUser = await prisma.staffUser.createMany({
     *   data: [
     *     // ... provide data here
     *   ]
     * })
     *
     */
    createMany<T extends StaffUserCreateManyArgs>(args?: Prisma.SelectSubset<T, StaffUserCreateManyArgs<ExtArgs>>): Prisma.PrismaPromise<Prisma.BatchPayload>;
    /**
     * Create many StaffUsers and returns the data saved in the database.
     * @param {StaffUserCreateManyAndReturnArgs} args - Arguments to create many StaffUsers.
     * @example
     * // Create many StaffUsers
     * const staffUser = await prisma.staffUser.createManyAndReturn({
     *   data: [
     *     // ... provide data here
     *   ]
     * })
     *
     * // Create many StaffUsers and only return the `id`
     * const staffUserWithIdOnly = await prisma.staffUser.createManyAndReturn({
     *   select: { id: true },
     *   data: [
     *     // ... provide data here
     *   ]
     * })
     * Note, that providing `undefined` is treated as the value not being there.
     * Read more here: https://pris.ly/d/null-undefined
     *
     */
    createManyAndReturn<T extends StaffUserCreateManyAndReturnArgs>(args?: Prisma.SelectSubset<T, StaffUserCreateManyAndReturnArgs<ExtArgs>>): Prisma.PrismaPromise<runtime.Types.Result.GetResult<Prisma.$StaffUserPayload<ExtArgs>, T, "createManyAndReturn", GlobalOmitOptions>>;
    /**
     * Delete a StaffUser.
     * @param {StaffUserDeleteArgs} args - Arguments to delete one StaffUser.
     * @example
     * // Delete one StaffUser
     * const StaffUser = await prisma.staffUser.delete({
     *   where: {
     *     // ... filter to delete one StaffUser
     *   }
     * })
     *
     */
    delete<T extends StaffUserDeleteArgs>(args: Prisma.SelectSubset<T, StaffUserDeleteArgs<ExtArgs>>): Prisma.Prisma__StaffUserClient<runtime.Types.Result.GetResult<Prisma.$StaffUserPayload<ExtArgs>, T, "delete", GlobalOmitOptions>, never, ExtArgs, GlobalOmitOptions>;
    /**
     * Update one StaffUser.
     * @param {StaffUserUpdateArgs} args - Arguments to update one StaffUser.
     * @example
     * // Update one StaffUser
     * const staffUser = await prisma.staffUser.update({
     *   where: {
     *     // ... provide filter here
     *   },
     *   data: {
     *     // ... provide data here
     *   }
     * })
     *
     */
    update<T extends StaffUserUpdateArgs>(args: Prisma.SelectSubset<T, StaffUserUpdateArgs<ExtArgs>>): Prisma.Prisma__StaffUserClient<runtime.Types.Result.GetResult<Prisma.$StaffUserPayload<ExtArgs>, T, "update", GlobalOmitOptions>, never, ExtArgs, GlobalOmitOptions>;
    /**
     * Delete zero or more StaffUsers.
     * @param {StaffUserDeleteManyArgs} args - Arguments to filter StaffUsers to delete.
     * @example
     * // Delete a few StaffUsers
     * const { count } = await prisma.staffUser.deleteMany({
     *   where: {
     *     // ... provide filter here
     *   }
     * })
     *
     */
    deleteMany<T extends StaffUserDeleteManyArgs>(args?: Prisma.SelectSubset<T, StaffUserDeleteManyArgs<ExtArgs>>): Prisma.PrismaPromise<Prisma.BatchPayload>;
    /**
     * Update zero or more StaffUsers.
     * Note, that providing `undefined` is treated as the value not being there.
     * Read more here: https://pris.ly/d/null-undefined
     * @param {StaffUserUpdateManyArgs} args - Arguments to update one or more rows.
     * @example
     * // Update many StaffUsers
     * const staffUser = await prisma.staffUser.updateMany({
     *   where: {
     *     // ... provide filter here
     *   },
     *   data: {
     *     // ... provide data here
     *   }
     * })
     *
     */
    updateMany<T extends StaffUserUpdateManyArgs>(args: Prisma.SelectSubset<T, StaffUserUpdateManyArgs<ExtArgs>>): Prisma.PrismaPromise<Prisma.BatchPayload>;
    /**
     * Update zero or more StaffUsers and returns the data updated in the database.
     * @param {StaffUserUpdateManyAndReturnArgs} args - Arguments to update many StaffUsers.
     * @example
     * // Update many StaffUsers
     * const staffUser = await prisma.staffUser.updateManyAndReturn({
     *   where: {
     *     // ... provide filter here
     *   },
     *   data: [
     *     // ... provide data here
     *   ]
     * })
     *
     * // Update zero or more StaffUsers and only return the `id`
     * const staffUserWithIdOnly = await prisma.staffUser.updateManyAndReturn({
     *   select: { id: true },
     *   where: {
     *     // ... provide filter here
     *   },
     *   data: [
     *     // ... provide data here
     *   ]
     * })
     * Note, that providing `undefined` is treated as the value not being there.
     * Read more here: https://pris.ly/d/null-undefined
     *
     */
    updateManyAndReturn<T extends StaffUserUpdateManyAndReturnArgs>(args: Prisma.SelectSubset<T, StaffUserUpdateManyAndReturnArgs<ExtArgs>>): Prisma.PrismaPromise<runtime.Types.Result.GetResult<Prisma.$StaffUserPayload<ExtArgs>, T, "updateManyAndReturn", GlobalOmitOptions>>;
    /**
     * Create or update one StaffUser.
     * @param {StaffUserUpsertArgs} args - Arguments to update or create a StaffUser.
     * @example
     * // Update or create a StaffUser
     * const staffUser = await prisma.staffUser.upsert({
     *   create: {
     *     // ... data to create a StaffUser
     *   },
     *   update: {
     *     // ... in case it already exists, update
     *   },
     *   where: {
     *     // ... the filter for the StaffUser we want to update
     *   }
     * })
     */
    upsert<T extends StaffUserUpsertArgs>(args: Prisma.SelectSubset<T, StaffUserUpsertArgs<ExtArgs>>): Prisma.Prisma__StaffUserClient<runtime.Types.Result.GetResult<Prisma.$StaffUserPayload<ExtArgs>, T, "upsert", GlobalOmitOptions>, never, ExtArgs, GlobalOmitOptions>;
    /**
     * Count the number of StaffUsers.
     * Note, that providing `undefined` is treated as the value not being there.
     * Read more here: https://pris.ly/d/null-undefined
     * @param {StaffUserCountArgs} args - Arguments to filter StaffUsers to count.
     * @example
     * // Count the number of StaffUsers
     * const count = await prisma.staffUser.count({
     *   where: {
     *     // ... the filter for the StaffUsers we want to count
     *   }
     * })
    **/
    count<T extends StaffUserCountArgs>(args?: Prisma.Subset<T, StaffUserCountArgs>): Prisma.PrismaPromise<T extends runtime.Types.Utils.Record<'select', any> ? T['select'] extends true ? number : Prisma.GetScalarType<T['select'], StaffUserCountAggregateOutputType> : number>;
    /**
     * Allows you to perform aggregations operations on a StaffUser.
     * Note, that providing `undefined` is treated as the value not being there.
     * Read more here: https://pris.ly/d/null-undefined
     * @param {StaffUserAggregateArgs} args - Select which aggregations you would like to apply and on what fields.
     * @example
     * // Ordered by age ascending
     * // Where email contains prisma.io
     * // Limited to the 10 users
     * const aggregations = await prisma.user.aggregate({
     *   _avg: {
     *     age: true,
     *   },
     *   where: {
     *     email: {
     *       contains: "prisma.io",
     *     },
     *   },
     *   orderBy: {
     *     age: "asc",
     *   },
     *   take: 10,
     * })
    **/
    aggregate<T extends StaffUserAggregateArgs>(args: Prisma.Subset<T, StaffUserAggregateArgs>): Prisma.PrismaPromise<GetStaffUserAggregateType<T>>;
    /**
     * Group by StaffUser.
     * Note, that providing `undefined` is treated as the value not being there.
     * Read more here: https://pris.ly/d/null-undefined
     * @param {StaffUserGroupByArgs} args - Group by arguments.
     * @example
     * // Group by city, order by createdAt, get count
     * const result = await prisma.user.groupBy({
     *   by: ['city', 'createdAt'],
     *   orderBy: {
     *     createdAt: true
     *   },
     *   _count: {
     *     _all: true
     *   },
     * })
     *
    **/
    groupBy<T extends StaffUserGroupByArgs, HasSelectOrTake extends Prisma.Or<Prisma.Extends<'skip', Prisma.Keys<T>>, Prisma.Extends<'take', Prisma.Keys<T>>>, OrderByArg extends Prisma.True extends HasSelectOrTake ? {
        orderBy: StaffUserGroupByArgs['orderBy'];
    } : {
        orderBy?: StaffUserGroupByArgs['orderBy'];
    }, OrderFields extends Prisma.ExcludeUnderscoreKeys<Prisma.Keys<Prisma.MaybeTupleToUnion<T['orderBy']>>>, ByFields extends Prisma.MaybeTupleToUnion<T['by']>, ByValid extends Prisma.Has<ByFields, OrderFields>, HavingFields extends Prisma.GetHavingFields<T['having']>, HavingValid extends Prisma.Has<ByFields, HavingFields>, ByEmpty extends T['by'] extends never[] ? Prisma.True : Prisma.False, InputErrors extends ByEmpty extends Prisma.True ? `Error: "by" must not be empty.` : HavingValid extends Prisma.False ? {
        [P in HavingFields]: P extends ByFields ? never : P extends string ? `Error: Field "${P}" used in "having" needs to be provided in "by".` : [
            Error,
            'Field ',
            P,
            ` in "having" needs to be provided in "by"`
        ];
    }[HavingFields] : 'take' extends Prisma.Keys<T> ? 'orderBy' extends Prisma.Keys<T> ? ByValid extends Prisma.True ? {} : {
        [P in OrderFields]: P extends ByFields ? never : `Error: Field "${P}" in "orderBy" needs to be provided in "by"`;
    }[OrderFields] : 'Error: If you provide "take", you also need to provide "orderBy"' : 'skip' extends Prisma.Keys<T> ? 'orderBy' extends Prisma.Keys<T> ? ByValid extends Prisma.True ? {} : {
        [P in OrderFields]: P extends ByFields ? never : `Error: Field "${P}" in "orderBy" needs to be provided in "by"`;
    }[OrderFields] : 'Error: If you provide "skip", you also need to provide "orderBy"' : ByValid extends Prisma.True ? {} : {
        [P in OrderFields]: P extends ByFields ? never : `Error: Field "${P}" in "orderBy" needs to be provided in "by"`;
    }[OrderFields]>(args: Prisma.SubsetIntersection<T, StaffUserGroupByArgs, OrderByArg> & InputErrors): {} extends InputErrors ? GetStaffUserGroupByPayload<T> : Prisma.PrismaPromise<InputErrors>;
    /**
     * Fields of the StaffUser model
     */
    readonly fields: StaffUserFieldRefs;
}
/**
 * The delegate class that acts as a "Promise-like" for StaffUser.
 * Why is this prefixed with `Prisma__`?
 * Because we want to prevent naming conflicts as mentioned in
 * https://github.com/prisma/prisma-client-js/issues/707
 */
export interface Prisma__StaffUserClient<T, Null = never, ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs, GlobalOmitOptions = {}> extends Prisma.PrismaPromise<T> {
    readonly [Symbol.toStringTag]: "PrismaPromise";
    referrals<T extends Prisma.StaffUser$referralsArgs<ExtArgs> = {}>(args?: Prisma.Subset<T, Prisma.StaffUser$referralsArgs<ExtArgs>>): Prisma.PrismaPromise<runtime.Types.Result.GetResult<Prisma.$ReferralPayload<ExtArgs>, T, "findMany", GlobalOmitOptions> | Null>;
    tips<T extends Prisma.StaffUser$tipsArgs<ExtArgs> = {}>(args?: Prisma.Subset<T, Prisma.StaffUser$tipsArgs<ExtArgs>>): Prisma.PrismaPromise<runtime.Types.Result.GetResult<Prisma.$TipPayload<ExtArgs>, T, "findMany", GlobalOmitOptions> | Null>;
    events<T extends Prisma.StaffUser$eventsArgs<ExtArgs> = {}>(args?: Prisma.Subset<T, Prisma.StaffUser$eventsArgs<ExtArgs>>): Prisma.PrismaPromise<runtime.Types.Result.GetResult<Prisma.$EventPayload<ExtArgs>, T, "findMany", GlobalOmitOptions> | Null>;
    /**
     * Attaches callbacks for the resolution and/or rejection of the Promise.
     * @param onfulfilled The callback to execute when the Promise is resolved.
     * @param onrejected The callback to execute when the Promise is rejected.
     * @returns A Promise for the completion of which ever callback is executed.
     */
    then<TResult1 = T, TResult2 = never>(onfulfilled?: ((value: T) => TResult1 | PromiseLike<TResult1>) | undefined | null, onrejected?: ((reason: any) => TResult2 | PromiseLike<TResult2>) | undefined | null): runtime.Types.Utils.JsPromise<TResult1 | TResult2>;
    /**
     * Attaches a callback for only the rejection of the Promise.
     * @param onrejected The callback to execute when the Promise is rejected.
     * @returns A Promise for the completion of the callback.
     */
    catch<TResult = never>(onrejected?: ((reason: any) => TResult | PromiseLike<TResult>) | undefined | null): runtime.Types.Utils.JsPromise<T | TResult>;
    /**
     * Attaches a callback that is invoked when the Promise is settled (fulfilled or rejected). The
     * resolved value cannot be modified from the callback.
     * @param onfinally The callback to execute when the Promise is settled (fulfilled or rejected).
     * @returns A Promise for the completion of the callback.
     */
    finally(onfinally?: (() => void) | undefined | null): runtime.Types.Utils.JsPromise<T>;
}
/**
 * Fields of the StaffUser model
 */
export interface StaffUserFieldRefs {
    readonly id: Prisma.FieldRef<"StaffUser", 'Int'>;
    readonly email: Prisma.FieldRef<"StaffUser", 'String'>;
    readonly passwordHash: Prisma.FieldRef<"StaffUser", 'String'>;
    readonly role: Prisma.FieldRef<"StaffUser", 'StaffRole'>;
    readonly createdAt: Prisma.FieldRef<"StaffUser", 'DateTime'>;
    readonly updatedAt: Prisma.FieldRef<"StaffUser", 'DateTime'>;
}
/**
 * StaffUser findUnique
 */
export type StaffUserFindUniqueArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    /**
     * Select specific fields to fetch from the StaffUser
     */
    select?: Prisma.StaffUserSelect<ExtArgs> | null;
    /**
     * Omit specific fields from the StaffUser
     */
    omit?: Prisma.StaffUserOmit<ExtArgs> | null;
    /**
     * Choose, which related nodes to fetch as well
     */
    include?: Prisma.StaffUserInclude<ExtArgs> | null;
    /**
     * Filter, which StaffUser to fetch.
     */
    where: Prisma.StaffUserWhereUniqueInput;
};
/**
 * StaffUser findUniqueOrThrow
 */
export type StaffUserFindUniqueOrThrowArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    /**
     * Select specific fields to fetch from the StaffUser
     */
    select?: Prisma.StaffUserSelect<ExtArgs> | null;
    /**
     * Omit specific fields from the StaffUser
     */
    omit?: Prisma.StaffUserOmit<ExtArgs> | null;
    /**
     * Choose, which related nodes to fetch as well
     */
    include?: Prisma.StaffUserInclude<ExtArgs> | null;
    /**
     * Filter, which StaffUser to fetch.
     */
    where: Prisma.StaffUserWhereUniqueInput;
};
/**
 * StaffUser findFirst
 */
export type StaffUserFindFirstArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    /**
     * Select specific fields to fetch from the StaffUser
     */
    select?: Prisma.StaffUserSelect<ExtArgs> | null;
    /**
     * Omit specific fields from the StaffUser
     */
    omit?: Prisma.StaffUserOmit<ExtArgs> | null;
    /**
     * Choose, which related nodes to fetch as well
     */
    include?: Prisma.StaffUserInclude<ExtArgs> | null;
    /**
     * Filter, which StaffUser to fetch.
     */
    where?: Prisma.StaffUserWhereInput;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/sorting Sorting Docs}
     *
     * Determine the order of StaffUsers to fetch.
     */
    orderBy?: Prisma.StaffUserOrderByWithRelationInput | Prisma.StaffUserOrderByWithRelationInput[];
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/pagination#cursor-based-pagination Cursor Docs}
     *
     * Sets the position for searching for StaffUsers.
     */
    cursor?: Prisma.StaffUserWhereUniqueInput;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/pagination Pagination Docs}
     *
     * Take `±n` StaffUsers from the position of the cursor.
     */
    take?: number;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/pagination Pagination Docs}
     *
     * Skip the first `n` StaffUsers.
     */
    skip?: number;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/distinct Distinct Docs}
     *
     * Filter by unique combinations of StaffUsers.
     */
    distinct?: Prisma.StaffUserScalarFieldEnum | Prisma.StaffUserScalarFieldEnum[];
};
/**
 * StaffUser findFirstOrThrow
 */
export type StaffUserFindFirstOrThrowArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    /**
     * Select specific fields to fetch from the StaffUser
     */
    select?: Prisma.StaffUserSelect<ExtArgs> | null;
    /**
     * Omit specific fields from the StaffUser
     */
    omit?: Prisma.StaffUserOmit<ExtArgs> | null;
    /**
     * Choose, which related nodes to fetch as well
     */
    include?: Prisma.StaffUserInclude<ExtArgs> | null;
    /**
     * Filter, which StaffUser to fetch.
     */
    where?: Prisma.StaffUserWhereInput;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/sorting Sorting Docs}
     *
     * Determine the order of StaffUsers to fetch.
     */
    orderBy?: Prisma.StaffUserOrderByWithRelationInput | Prisma.StaffUserOrderByWithRelationInput[];
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/pagination#cursor-based-pagination Cursor Docs}
     *
     * Sets the position for searching for StaffUsers.
     */
    cursor?: Prisma.StaffUserWhereUniqueInput;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/pagination Pagination Docs}
     *
     * Take `±n` StaffUsers from the position of the cursor.
     */
    take?: number;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/pagination Pagination Docs}
     *
     * Skip the first `n` StaffUsers.
     */
    skip?: number;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/distinct Distinct Docs}
     *
     * Filter by unique combinations of StaffUsers.
     */
    distinct?: Prisma.StaffUserScalarFieldEnum | Prisma.StaffUserScalarFieldEnum[];
};
/**
 * StaffUser findMany
 */
export type StaffUserFindManyArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    /**
     * Select specific fields to fetch from the StaffUser
     */
    select?: Prisma.StaffUserSelect<ExtArgs> | null;
    /**
     * Omit specific fields from the StaffUser
     */
    omit?: Prisma.StaffUserOmit<ExtArgs> | null;
    /**
     * Choose, which related nodes to fetch as well
     */
    include?: Prisma.StaffUserInclude<ExtArgs> | null;
    /**
     * Filter, which StaffUsers to fetch.
     */
    where?: Prisma.StaffUserWhereInput;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/sorting Sorting Docs}
     *
     * Determine the order of StaffUsers to fetch.
     */
    orderBy?: Prisma.StaffUserOrderByWithRelationInput | Prisma.StaffUserOrderByWithRelationInput[];
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/pagination#cursor-based-pagination Cursor Docs}
     *
     * Sets the position for listing StaffUsers.
     */
    cursor?: Prisma.StaffUserWhereUniqueInput;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/pagination Pagination Docs}
     *
     * Take `±n` StaffUsers from the position of the cursor.
     */
    take?: number;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/pagination Pagination Docs}
     *
     * Skip the first `n` StaffUsers.
     */
    skip?: number;
    distinct?: Prisma.StaffUserScalarFieldEnum | Prisma.StaffUserScalarFieldEnum[];
};
/**
 * StaffUser create
 */
export type StaffUserCreateArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    /**
     * Select specific fields to fetch from the StaffUser
     */
    select?: Prisma.StaffUserSelect<ExtArgs> | null;
    /**
     * Omit specific fields from the StaffUser
     */
    omit?: Prisma.StaffUserOmit<ExtArgs> | null;
    /**
     * Choose, which related nodes to fetch as well
     */
    include?: Prisma.StaffUserInclude<ExtArgs> | null;
    /**
     * The data needed to create a StaffUser.
     */
    data: Prisma.XOR<Prisma.StaffUserCreateInput, Prisma.StaffUserUncheckedCreateInput>;
};
/**
 * StaffUser createMany
 */
export type StaffUserCreateManyArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    /**
     * The data used to create many StaffUsers.
     */
    data: Prisma.StaffUserCreateManyInput | Prisma.StaffUserCreateManyInput[];
};
/**
 * StaffUser createManyAndReturn
 */
export type StaffUserCreateManyAndReturnArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    /**
     * Select specific fields to fetch from the StaffUser
     */
    select?: Prisma.StaffUserSelectCreateManyAndReturn<ExtArgs> | null;
    /**
     * Omit specific fields from the StaffUser
     */
    omit?: Prisma.StaffUserOmit<ExtArgs> | null;
    /**
     * The data used to create many StaffUsers.
     */
    data: Prisma.StaffUserCreateManyInput | Prisma.StaffUserCreateManyInput[];
};
/**
 * StaffUser update
 */
export type StaffUserUpdateArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    /**
     * Select specific fields to fetch from the StaffUser
     */
    select?: Prisma.StaffUserSelect<ExtArgs> | null;
    /**
     * Omit specific fields from the StaffUser
     */
    omit?: Prisma.StaffUserOmit<ExtArgs> | null;
    /**
     * Choose, which related nodes to fetch as well
     */
    include?: Prisma.StaffUserInclude<ExtArgs> | null;
    /**
     * The data needed to update a StaffUser.
     */
    data: Prisma.XOR<Prisma.StaffUserUpdateInput, Prisma.StaffUserUncheckedUpdateInput>;
    /**
     * Choose, which StaffUser to update.
     */
    where: Prisma.StaffUserWhereUniqueInput;
};
/**
 * StaffUser updateMany
 */
export type StaffUserUpdateManyArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    /**
     * The data used to update StaffUsers.
     */
    data: Prisma.XOR<Prisma.StaffUserUpdateManyMutationInput, Prisma.StaffUserUncheckedUpdateManyInput>;
    /**
     * Filter which StaffUsers to update
     */
    where?: Prisma.StaffUserWhereInput;
    /**
     * Limit how many StaffUsers to update.
     */
    limit?: number;
};
/**
 * StaffUser updateManyAndReturn
 */
export type StaffUserUpdateManyAndReturnArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    /**
     * Select specific fields to fetch from the StaffUser
     */
    select?: Prisma.StaffUserSelectUpdateManyAndReturn<ExtArgs> | null;
    /**
     * Omit specific fields from the StaffUser
     */
    omit?: Prisma.StaffUserOmit<ExtArgs> | null;
    /**
     * The data used to update StaffUsers.
     */
    data: Prisma.XOR<Prisma.StaffUserUpdateManyMutationInput, Prisma.StaffUserUncheckedUpdateManyInput>;
    /**
     * Filter which StaffUsers to update
     */
    where?: Prisma.StaffUserWhereInput;
    /**
     * Limit how many StaffUsers to update.
     */
    limit?: number;
};
/**
 * StaffUser upsert
 */
export type StaffUserUpsertArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    /**
     * Select specific fields to fetch from the StaffUser
     */
    select?: Prisma.StaffUserSelect<ExtArgs> | null;
    /**
     * Omit specific fields from the StaffUser
     */
    omit?: Prisma.StaffUserOmit<ExtArgs> | null;
    /**
     * Choose, which related nodes to fetch as well
     */
    include?: Prisma.StaffUserInclude<ExtArgs> | null;
    /**
     * The filter to search for the StaffUser to update in case it exists.
     */
    where: Prisma.StaffUserWhereUniqueInput;
    /**
     * In case the StaffUser found by the `where` argument doesn't exist, create a new StaffUser with this data.
     */
    create: Prisma.XOR<Prisma.StaffUserCreateInput, Prisma.StaffUserUncheckedCreateInput>;
    /**
     * In case the StaffUser was found with the provided `where` argument, update it with this data.
     */
    update: Prisma.XOR<Prisma.StaffUserUpdateInput, Prisma.StaffUserUncheckedUpdateInput>;
};
/**
 * StaffUser delete
 */
export type StaffUserDeleteArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    /**
     * Select specific fields to fetch from the StaffUser
     */
    select?: Prisma.StaffUserSelect<ExtArgs> | null;
    /**
     * Omit specific fields from the StaffUser
     */
    omit?: Prisma.StaffUserOmit<ExtArgs> | null;
    /**
     * Choose, which related nodes to fetch as well
     */
    include?: Prisma.StaffUserInclude<ExtArgs> | null;
    /**
     * Filter which StaffUser to delete.
     */
    where: Prisma.StaffUserWhereUniqueInput;
};
/**
 * StaffUser deleteMany
 */
export type StaffUserDeleteManyArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    /**
     * Filter which StaffUsers to delete
     */
    where?: Prisma.StaffUserWhereInput;
    /**
     * Limit how many StaffUsers to delete.
     */
    limit?: number;
};
/**
 * StaffUser.referrals
 */
export type StaffUser$referralsArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    /**
     * Select specific fields to fetch from the Referral
     */
    select?: Prisma.ReferralSelect<ExtArgs> | null;
    /**
     * Omit specific fields from the Referral
     */
    omit?: Prisma.ReferralOmit<ExtArgs> | null;
    /**
     * Choose, which related nodes to fetch as well
     */
    include?: Prisma.ReferralInclude<ExtArgs> | null;
    where?: Prisma.ReferralWhereInput;
    orderBy?: Prisma.ReferralOrderByWithRelationInput | Prisma.ReferralOrderByWithRelationInput[];
    cursor?: Prisma.ReferralWhereUniqueInput;
    take?: number;
    skip?: number;
    distinct?: Prisma.ReferralScalarFieldEnum | Prisma.ReferralScalarFieldEnum[];
};
/**
 * StaffUser.tips
 */
export type StaffUser$tipsArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    /**
     * Select specific fields to fetch from the Tip
     */
    select?: Prisma.TipSelect<ExtArgs> | null;
    /**
     * Omit specific fields from the Tip
     */
    omit?: Prisma.TipOmit<ExtArgs> | null;
    /**
     * Choose, which related nodes to fetch as well
     */
    include?: Prisma.TipInclude<ExtArgs> | null;
    where?: Prisma.TipWhereInput;
    orderBy?: Prisma.TipOrderByWithRelationInput | Prisma.TipOrderByWithRelationInput[];
    cursor?: Prisma.TipWhereUniqueInput;
    take?: number;
    skip?: number;
    distinct?: Prisma.TipScalarFieldEnum | Prisma.TipScalarFieldEnum[];
};
/**
 * StaffUser.events
 */
export type StaffUser$eventsArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    /**
     * Select specific fields to fetch from the Event
     */
    select?: Prisma.EventSelect<ExtArgs> | null;
    /**
     * Omit specific fields from the Event
     */
    omit?: Prisma.EventOmit<ExtArgs> | null;
    /**
     * Choose, which related nodes to fetch as well
     */
    include?: Prisma.EventInclude<ExtArgs> | null;
    where?: Prisma.EventWhereInput;
    orderBy?: Prisma.EventOrderByWithRelationInput | Prisma.EventOrderByWithRelationInput[];
    cursor?: Prisma.EventWhereUniqueInput;
    take?: number;
    skip?: number;
    distinct?: Prisma.EventScalarFieldEnum | Prisma.EventScalarFieldEnum[];
};
/**
 * StaffUser without action
 */
export type StaffUserDefaultArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    /**
     * Select specific fields to fetch from the StaffUser
     */
    select?: Prisma.StaffUserSelect<ExtArgs> | null;
    /**
     * Omit specific fields from the StaffUser
     */
    omit?: Prisma.StaffUserOmit<ExtArgs> | null;
    /**
     * Choose, which related nodes to fetch as well
     */
    include?: Prisma.StaffUserInclude<ExtArgs> | null;
};
export {};
//# sourceMappingURL=StaffUser.d.ts.map