import type * as runtime from "@prisma/client/runtime/library";
import type * as Prisma from "../internal/prismaNamespace";
/**
 * Model Referral
 *
 */
export type ReferralModel = runtime.Types.Result.DefaultSelection<Prisma.$ReferralPayload>;
export type AggregateReferral = {
    _count: ReferralCountAggregateOutputType | null;
    _avg: ReferralAvgAggregateOutputType | null;
    _sum: ReferralSumAggregateOutputType | null;
    _min: ReferralMinAggregateOutputType | null;
    _max: ReferralMaxAggregateOutputType | null;
};
export type ReferralAvgAggregateOutputType = {
    id: number | null;
    createdById: number | null;
};
export type ReferralSumAggregateOutputType = {
    id: number | null;
    createdById: number | null;
};
export type ReferralMinAggregateOutputType = {
    id: number | null;
    organisationName: string | null;
    category: string | null;
    website: string | null;
    phone: string | null;
    services: string | null;
    demographics: string | null;
    availability: string | null;
    email: string | null;
    address: string | null;
    region: string | null;
    notes: string | null;
    isActive: boolean | null;
    createdAt: Date | null;
    updatedAt: Date | null;
    createdById: number | null;
};
export type ReferralMaxAggregateOutputType = {
    id: number | null;
    organisationName: string | null;
    category: string | null;
    website: string | null;
    phone: string | null;
    services: string | null;
    demographics: string | null;
    availability: string | null;
    email: string | null;
    address: string | null;
    region: string | null;
    notes: string | null;
    isActive: boolean | null;
    createdAt: Date | null;
    updatedAt: Date | null;
    createdById: number | null;
};
export type ReferralCountAggregateOutputType = {
    id: number;
    organisationName: number;
    category: number;
    website: number;
    phone: number;
    services: number;
    demographics: number;
    availability: number;
    email: number;
    address: number;
    region: number;
    notes: number;
    isActive: number;
    createdAt: number;
    updatedAt: number;
    createdById: number;
    _all: number;
};
export type ReferralAvgAggregateInputType = {
    id?: true;
    createdById?: true;
};
export type ReferralSumAggregateInputType = {
    id?: true;
    createdById?: true;
};
export type ReferralMinAggregateInputType = {
    id?: true;
    organisationName?: true;
    category?: true;
    website?: true;
    phone?: true;
    services?: true;
    demographics?: true;
    availability?: true;
    email?: true;
    address?: true;
    region?: true;
    notes?: true;
    isActive?: true;
    createdAt?: true;
    updatedAt?: true;
    createdById?: true;
};
export type ReferralMaxAggregateInputType = {
    id?: true;
    organisationName?: true;
    category?: true;
    website?: true;
    phone?: true;
    services?: true;
    demographics?: true;
    availability?: true;
    email?: true;
    address?: true;
    region?: true;
    notes?: true;
    isActive?: true;
    createdAt?: true;
    updatedAt?: true;
    createdById?: true;
};
export type ReferralCountAggregateInputType = {
    id?: true;
    organisationName?: true;
    category?: true;
    website?: true;
    phone?: true;
    services?: true;
    demographics?: true;
    availability?: true;
    email?: true;
    address?: true;
    region?: true;
    notes?: true;
    isActive?: true;
    createdAt?: true;
    updatedAt?: true;
    createdById?: true;
    _all?: true;
};
export type ReferralAggregateArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    /**
     * Filter which Referral to aggregate.
     */
    where?: Prisma.ReferralWhereInput;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/sorting Sorting Docs}
     *
     * Determine the order of Referrals to fetch.
     */
    orderBy?: Prisma.ReferralOrderByWithRelationInput | Prisma.ReferralOrderByWithRelationInput[];
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/pagination#cursor-based-pagination Cursor Docs}
     *
     * Sets the start position
     */
    cursor?: Prisma.ReferralWhereUniqueInput;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/pagination Pagination Docs}
     *
     * Take `±n` Referrals from the position of the cursor.
     */
    take?: number;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/pagination Pagination Docs}
     *
     * Skip the first `n` Referrals.
     */
    skip?: number;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/aggregations Aggregation Docs}
     *
     * Count returned Referrals
    **/
    _count?: true | ReferralCountAggregateInputType;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/aggregations Aggregation Docs}
     *
     * Select which fields to average
    **/
    _avg?: ReferralAvgAggregateInputType;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/aggregations Aggregation Docs}
     *
     * Select which fields to sum
    **/
    _sum?: ReferralSumAggregateInputType;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/aggregations Aggregation Docs}
     *
     * Select which fields to find the minimum value
    **/
    _min?: ReferralMinAggregateInputType;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/aggregations Aggregation Docs}
     *
     * Select which fields to find the maximum value
    **/
    _max?: ReferralMaxAggregateInputType;
};
export type GetReferralAggregateType<T extends ReferralAggregateArgs> = {
    [P in keyof T & keyof AggregateReferral]: P extends '_count' | 'count' ? T[P] extends true ? number : Prisma.GetScalarType<T[P], AggregateReferral[P]> : Prisma.GetScalarType<T[P], AggregateReferral[P]>;
};
export type ReferralGroupByArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    where?: Prisma.ReferralWhereInput;
    orderBy?: Prisma.ReferralOrderByWithAggregationInput | Prisma.ReferralOrderByWithAggregationInput[];
    by: Prisma.ReferralScalarFieldEnum[] | Prisma.ReferralScalarFieldEnum;
    having?: Prisma.ReferralScalarWhereWithAggregatesInput;
    take?: number;
    skip?: number;
    _count?: ReferralCountAggregateInputType | true;
    _avg?: ReferralAvgAggregateInputType;
    _sum?: ReferralSumAggregateInputType;
    _min?: ReferralMinAggregateInputType;
    _max?: ReferralMaxAggregateInputType;
};
export type ReferralGroupByOutputType = {
    id: number;
    organisationName: string | null;
    category: string | null;
    website: string | null;
    phone: string | null;
    services: string | null;
    demographics: string | null;
    availability: string | null;
    email: string | null;
    address: string | null;
    region: string | null;
    notes: string | null;
    isActive: boolean;
    createdAt: Date;
    updatedAt: Date;
    createdById: number | null;
    _count: ReferralCountAggregateOutputType | null;
    _avg: ReferralAvgAggregateOutputType | null;
    _sum: ReferralSumAggregateOutputType | null;
    _min: ReferralMinAggregateOutputType | null;
    _max: ReferralMaxAggregateOutputType | null;
};
type GetReferralGroupByPayload<T extends ReferralGroupByArgs> = Prisma.PrismaPromise<Array<Prisma.PickEnumerable<ReferralGroupByOutputType, T['by']> & {
    [P in ((keyof T) & (keyof ReferralGroupByOutputType))]: P extends '_count' ? T[P] extends boolean ? number : Prisma.GetScalarType<T[P], ReferralGroupByOutputType[P]> : Prisma.GetScalarType<T[P], ReferralGroupByOutputType[P]>;
}>>;
export type ReferralWhereInput = {
    AND?: Prisma.ReferralWhereInput | Prisma.ReferralWhereInput[];
    OR?: Prisma.ReferralWhereInput[];
    NOT?: Prisma.ReferralWhereInput | Prisma.ReferralWhereInput[];
    id?: Prisma.IntFilter<"Referral"> | number;
    organisationName?: Prisma.StringNullableFilter<"Referral"> | string | null;
    category?: Prisma.StringNullableFilter<"Referral"> | string | null;
    website?: Prisma.StringNullableFilter<"Referral"> | string | null;
    phone?: Prisma.StringNullableFilter<"Referral"> | string | null;
    services?: Prisma.StringNullableFilter<"Referral"> | string | null;
    demographics?: Prisma.StringNullableFilter<"Referral"> | string | null;
    availability?: Prisma.StringNullableFilter<"Referral"> | string | null;
    email?: Prisma.StringNullableFilter<"Referral"> | string | null;
    address?: Prisma.StringNullableFilter<"Referral"> | string | null;
    region?: Prisma.StringNullableFilter<"Referral"> | string | null;
    notes?: Prisma.StringNullableFilter<"Referral"> | string | null;
    isActive?: Prisma.BoolFilter<"Referral"> | boolean;
    createdAt?: Prisma.DateTimeFilter<"Referral"> | Date | string;
    updatedAt?: Prisma.DateTimeFilter<"Referral"> | Date | string;
    createdById?: Prisma.IntNullableFilter<"Referral"> | number | null;
    createdBy?: Prisma.XOR<Prisma.StaffUserNullableScalarRelationFilter, Prisma.StaffUserWhereInput> | null;
};
export type ReferralOrderByWithRelationInput = {
    id?: Prisma.SortOrder;
    organisationName?: Prisma.SortOrderInput | Prisma.SortOrder;
    category?: Prisma.SortOrderInput | Prisma.SortOrder;
    website?: Prisma.SortOrderInput | Prisma.SortOrder;
    phone?: Prisma.SortOrderInput | Prisma.SortOrder;
    services?: Prisma.SortOrderInput | Prisma.SortOrder;
    demographics?: Prisma.SortOrderInput | Prisma.SortOrder;
    availability?: Prisma.SortOrderInput | Prisma.SortOrder;
    email?: Prisma.SortOrderInput | Prisma.SortOrder;
    address?: Prisma.SortOrderInput | Prisma.SortOrder;
    region?: Prisma.SortOrderInput | Prisma.SortOrder;
    notes?: Prisma.SortOrderInput | Prisma.SortOrder;
    isActive?: Prisma.SortOrder;
    createdAt?: Prisma.SortOrder;
    updatedAt?: Prisma.SortOrder;
    createdById?: Prisma.SortOrderInput | Prisma.SortOrder;
    createdBy?: Prisma.StaffUserOrderByWithRelationInput;
};
export type ReferralWhereUniqueInput = Prisma.AtLeast<{
    id?: number;
    AND?: Prisma.ReferralWhereInput | Prisma.ReferralWhereInput[];
    OR?: Prisma.ReferralWhereInput[];
    NOT?: Prisma.ReferralWhereInput | Prisma.ReferralWhereInput[];
    organisationName?: Prisma.StringNullableFilter<"Referral"> | string | null;
    category?: Prisma.StringNullableFilter<"Referral"> | string | null;
    website?: Prisma.StringNullableFilter<"Referral"> | string | null;
    phone?: Prisma.StringNullableFilter<"Referral"> | string | null;
    services?: Prisma.StringNullableFilter<"Referral"> | string | null;
    demographics?: Prisma.StringNullableFilter<"Referral"> | string | null;
    availability?: Prisma.StringNullableFilter<"Referral"> | string | null;
    email?: Prisma.StringNullableFilter<"Referral"> | string | null;
    address?: Prisma.StringNullableFilter<"Referral"> | string | null;
    region?: Prisma.StringNullableFilter<"Referral"> | string | null;
    notes?: Prisma.StringNullableFilter<"Referral"> | string | null;
    isActive?: Prisma.BoolFilter<"Referral"> | boolean;
    createdAt?: Prisma.DateTimeFilter<"Referral"> | Date | string;
    updatedAt?: Prisma.DateTimeFilter<"Referral"> | Date | string;
    createdById?: Prisma.IntNullableFilter<"Referral"> | number | null;
    createdBy?: Prisma.XOR<Prisma.StaffUserNullableScalarRelationFilter, Prisma.StaffUserWhereInput> | null;
}, "id">;
export type ReferralOrderByWithAggregationInput = {
    id?: Prisma.SortOrder;
    organisationName?: Prisma.SortOrderInput | Prisma.SortOrder;
    category?: Prisma.SortOrderInput | Prisma.SortOrder;
    website?: Prisma.SortOrderInput | Prisma.SortOrder;
    phone?: Prisma.SortOrderInput | Prisma.SortOrder;
    services?: Prisma.SortOrderInput | Prisma.SortOrder;
    demographics?: Prisma.SortOrderInput | Prisma.SortOrder;
    availability?: Prisma.SortOrderInput | Prisma.SortOrder;
    email?: Prisma.SortOrderInput | Prisma.SortOrder;
    address?: Prisma.SortOrderInput | Prisma.SortOrder;
    region?: Prisma.SortOrderInput | Prisma.SortOrder;
    notes?: Prisma.SortOrderInput | Prisma.SortOrder;
    isActive?: Prisma.SortOrder;
    createdAt?: Prisma.SortOrder;
    updatedAt?: Prisma.SortOrder;
    createdById?: Prisma.SortOrderInput | Prisma.SortOrder;
    _count?: Prisma.ReferralCountOrderByAggregateInput;
    _avg?: Prisma.ReferralAvgOrderByAggregateInput;
    _max?: Prisma.ReferralMaxOrderByAggregateInput;
    _min?: Prisma.ReferralMinOrderByAggregateInput;
    _sum?: Prisma.ReferralSumOrderByAggregateInput;
};
export type ReferralScalarWhereWithAggregatesInput = {
    AND?: Prisma.ReferralScalarWhereWithAggregatesInput | Prisma.ReferralScalarWhereWithAggregatesInput[];
    OR?: Prisma.ReferralScalarWhereWithAggregatesInput[];
    NOT?: Prisma.ReferralScalarWhereWithAggregatesInput | Prisma.ReferralScalarWhereWithAggregatesInput[];
    id?: Prisma.IntWithAggregatesFilter<"Referral"> | number;
    organisationName?: Prisma.StringNullableWithAggregatesFilter<"Referral"> | string | null;
    category?: Prisma.StringNullableWithAggregatesFilter<"Referral"> | string | null;
    website?: Prisma.StringNullableWithAggregatesFilter<"Referral"> | string | null;
    phone?: Prisma.StringNullableWithAggregatesFilter<"Referral"> | string | null;
    services?: Prisma.StringNullableWithAggregatesFilter<"Referral"> | string | null;
    demographics?: Prisma.StringNullableWithAggregatesFilter<"Referral"> | string | null;
    availability?: Prisma.StringNullableWithAggregatesFilter<"Referral"> | string | null;
    email?: Prisma.StringNullableWithAggregatesFilter<"Referral"> | string | null;
    address?: Prisma.StringNullableWithAggregatesFilter<"Referral"> | string | null;
    region?: Prisma.StringNullableWithAggregatesFilter<"Referral"> | string | null;
    notes?: Prisma.StringNullableWithAggregatesFilter<"Referral"> | string | null;
    isActive?: Prisma.BoolWithAggregatesFilter<"Referral"> | boolean;
    createdAt?: Prisma.DateTimeWithAggregatesFilter<"Referral"> | Date | string;
    updatedAt?: Prisma.DateTimeWithAggregatesFilter<"Referral"> | Date | string;
    createdById?: Prisma.IntNullableWithAggregatesFilter<"Referral"> | number | null;
};
export type ReferralCreateInput = {
    organisationName?: string | null;
    category?: string | null;
    website?: string | null;
    phone?: string | null;
    services?: string | null;
    demographics?: string | null;
    availability?: string | null;
    email?: string | null;
    address?: string | null;
    region?: string | null;
    notes?: string | null;
    isActive?: boolean;
    createdAt?: Date | string;
    updatedAt?: Date | string;
    createdBy?: Prisma.StaffUserCreateNestedOneWithoutReferralsInput;
};
export type ReferralUncheckedCreateInput = {
    id?: number;
    organisationName?: string | null;
    category?: string | null;
    website?: string | null;
    phone?: string | null;
    services?: string | null;
    demographics?: string | null;
    availability?: string | null;
    email?: string | null;
    address?: string | null;
    region?: string | null;
    notes?: string | null;
    isActive?: boolean;
    createdAt?: Date | string;
    updatedAt?: Date | string;
    createdById?: number | null;
};
export type ReferralUpdateInput = {
    organisationName?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    category?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    website?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    phone?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    services?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    demographics?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    availability?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    email?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    address?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    region?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    notes?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    isActive?: Prisma.BoolFieldUpdateOperationsInput | boolean;
    createdAt?: Prisma.DateTimeFieldUpdateOperationsInput | Date | string;
    updatedAt?: Prisma.DateTimeFieldUpdateOperationsInput | Date | string;
    createdBy?: Prisma.StaffUserUpdateOneWithoutReferralsNestedInput;
};
export type ReferralUncheckedUpdateInput = {
    id?: Prisma.IntFieldUpdateOperationsInput | number;
    organisationName?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    category?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    website?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    phone?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    services?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    demographics?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    availability?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    email?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    address?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    region?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    notes?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    isActive?: Prisma.BoolFieldUpdateOperationsInput | boolean;
    createdAt?: Prisma.DateTimeFieldUpdateOperationsInput | Date | string;
    updatedAt?: Prisma.DateTimeFieldUpdateOperationsInput | Date | string;
    createdById?: Prisma.NullableIntFieldUpdateOperationsInput | number | null;
};
export type ReferralCreateManyInput = {
    id?: number;
    organisationName?: string | null;
    category?: string | null;
    website?: string | null;
    phone?: string | null;
    services?: string | null;
    demographics?: string | null;
    availability?: string | null;
    email?: string | null;
    address?: string | null;
    region?: string | null;
    notes?: string | null;
    isActive?: boolean;
    createdAt?: Date | string;
    updatedAt?: Date | string;
    createdById?: number | null;
};
export type ReferralUpdateManyMutationInput = {
    organisationName?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    category?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    website?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    phone?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    services?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    demographics?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    availability?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    email?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    address?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    region?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    notes?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    isActive?: Prisma.BoolFieldUpdateOperationsInput | boolean;
    createdAt?: Prisma.DateTimeFieldUpdateOperationsInput | Date | string;
    updatedAt?: Prisma.DateTimeFieldUpdateOperationsInput | Date | string;
};
export type ReferralUncheckedUpdateManyInput = {
    id?: Prisma.IntFieldUpdateOperationsInput | number;
    organisationName?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    category?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    website?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    phone?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    services?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    demographics?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    availability?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    email?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    address?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    region?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    notes?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    isActive?: Prisma.BoolFieldUpdateOperationsInput | boolean;
    createdAt?: Prisma.DateTimeFieldUpdateOperationsInput | Date | string;
    updatedAt?: Prisma.DateTimeFieldUpdateOperationsInput | Date | string;
    createdById?: Prisma.NullableIntFieldUpdateOperationsInput | number | null;
};
export type ReferralListRelationFilter = {
    every?: Prisma.ReferralWhereInput;
    some?: Prisma.ReferralWhereInput;
    none?: Prisma.ReferralWhereInput;
};
export type ReferralOrderByRelationAggregateInput = {
    _count?: Prisma.SortOrder;
};
export type ReferralCountOrderByAggregateInput = {
    id?: Prisma.SortOrder;
    organisationName?: Prisma.SortOrder;
    category?: Prisma.SortOrder;
    website?: Prisma.SortOrder;
    phone?: Prisma.SortOrder;
    services?: Prisma.SortOrder;
    demographics?: Prisma.SortOrder;
    availability?: Prisma.SortOrder;
    email?: Prisma.SortOrder;
    address?: Prisma.SortOrder;
    region?: Prisma.SortOrder;
    notes?: Prisma.SortOrder;
    isActive?: Prisma.SortOrder;
    createdAt?: Prisma.SortOrder;
    updatedAt?: Prisma.SortOrder;
    createdById?: Prisma.SortOrder;
};
export type ReferralAvgOrderByAggregateInput = {
    id?: Prisma.SortOrder;
    createdById?: Prisma.SortOrder;
};
export type ReferralMaxOrderByAggregateInput = {
    id?: Prisma.SortOrder;
    organisationName?: Prisma.SortOrder;
    category?: Prisma.SortOrder;
    website?: Prisma.SortOrder;
    phone?: Prisma.SortOrder;
    services?: Prisma.SortOrder;
    demographics?: Prisma.SortOrder;
    availability?: Prisma.SortOrder;
    email?: Prisma.SortOrder;
    address?: Prisma.SortOrder;
    region?: Prisma.SortOrder;
    notes?: Prisma.SortOrder;
    isActive?: Prisma.SortOrder;
    createdAt?: Prisma.SortOrder;
    updatedAt?: Prisma.SortOrder;
    createdById?: Prisma.SortOrder;
};
export type ReferralMinOrderByAggregateInput = {
    id?: Prisma.SortOrder;
    organisationName?: Prisma.SortOrder;
    category?: Prisma.SortOrder;
    website?: Prisma.SortOrder;
    phone?: Prisma.SortOrder;
    services?: Prisma.SortOrder;
    demographics?: Prisma.SortOrder;
    availability?: Prisma.SortOrder;
    email?: Prisma.SortOrder;
    address?: Prisma.SortOrder;
    region?: Prisma.SortOrder;
    notes?: Prisma.SortOrder;
    isActive?: Prisma.SortOrder;
    createdAt?: Prisma.SortOrder;
    updatedAt?: Prisma.SortOrder;
    createdById?: Prisma.SortOrder;
};
export type ReferralSumOrderByAggregateInput = {
    id?: Prisma.SortOrder;
    createdById?: Prisma.SortOrder;
};
export type ReferralCreateNestedManyWithoutCreatedByInput = {
    create?: Prisma.XOR<Prisma.ReferralCreateWithoutCreatedByInput, Prisma.ReferralUncheckedCreateWithoutCreatedByInput> | Prisma.ReferralCreateWithoutCreatedByInput[] | Prisma.ReferralUncheckedCreateWithoutCreatedByInput[];
    connectOrCreate?: Prisma.ReferralCreateOrConnectWithoutCreatedByInput | Prisma.ReferralCreateOrConnectWithoutCreatedByInput[];
    createMany?: Prisma.ReferralCreateManyCreatedByInputEnvelope;
    connect?: Prisma.ReferralWhereUniqueInput | Prisma.ReferralWhereUniqueInput[];
};
export type ReferralUncheckedCreateNestedManyWithoutCreatedByInput = {
    create?: Prisma.XOR<Prisma.ReferralCreateWithoutCreatedByInput, Prisma.ReferralUncheckedCreateWithoutCreatedByInput> | Prisma.ReferralCreateWithoutCreatedByInput[] | Prisma.ReferralUncheckedCreateWithoutCreatedByInput[];
    connectOrCreate?: Prisma.ReferralCreateOrConnectWithoutCreatedByInput | Prisma.ReferralCreateOrConnectWithoutCreatedByInput[];
    createMany?: Prisma.ReferralCreateManyCreatedByInputEnvelope;
    connect?: Prisma.ReferralWhereUniqueInput | Prisma.ReferralWhereUniqueInput[];
};
export type ReferralUpdateManyWithoutCreatedByNestedInput = {
    create?: Prisma.XOR<Prisma.ReferralCreateWithoutCreatedByInput, Prisma.ReferralUncheckedCreateWithoutCreatedByInput> | Prisma.ReferralCreateWithoutCreatedByInput[] | Prisma.ReferralUncheckedCreateWithoutCreatedByInput[];
    connectOrCreate?: Prisma.ReferralCreateOrConnectWithoutCreatedByInput | Prisma.ReferralCreateOrConnectWithoutCreatedByInput[];
    upsert?: Prisma.ReferralUpsertWithWhereUniqueWithoutCreatedByInput | Prisma.ReferralUpsertWithWhereUniqueWithoutCreatedByInput[];
    createMany?: Prisma.ReferralCreateManyCreatedByInputEnvelope;
    set?: Prisma.ReferralWhereUniqueInput | Prisma.ReferralWhereUniqueInput[];
    disconnect?: Prisma.ReferralWhereUniqueInput | Prisma.ReferralWhereUniqueInput[];
    delete?: Prisma.ReferralWhereUniqueInput | Prisma.ReferralWhereUniqueInput[];
    connect?: Prisma.ReferralWhereUniqueInput | Prisma.ReferralWhereUniqueInput[];
    update?: Prisma.ReferralUpdateWithWhereUniqueWithoutCreatedByInput | Prisma.ReferralUpdateWithWhereUniqueWithoutCreatedByInput[];
    updateMany?: Prisma.ReferralUpdateManyWithWhereWithoutCreatedByInput | Prisma.ReferralUpdateManyWithWhereWithoutCreatedByInput[];
    deleteMany?: Prisma.ReferralScalarWhereInput | Prisma.ReferralScalarWhereInput[];
};
export type ReferralUncheckedUpdateManyWithoutCreatedByNestedInput = {
    create?: Prisma.XOR<Prisma.ReferralCreateWithoutCreatedByInput, Prisma.ReferralUncheckedCreateWithoutCreatedByInput> | Prisma.ReferralCreateWithoutCreatedByInput[] | Prisma.ReferralUncheckedCreateWithoutCreatedByInput[];
    connectOrCreate?: Prisma.ReferralCreateOrConnectWithoutCreatedByInput | Prisma.ReferralCreateOrConnectWithoutCreatedByInput[];
    upsert?: Prisma.ReferralUpsertWithWhereUniqueWithoutCreatedByInput | Prisma.ReferralUpsertWithWhereUniqueWithoutCreatedByInput[];
    createMany?: Prisma.ReferralCreateManyCreatedByInputEnvelope;
    set?: Prisma.ReferralWhereUniqueInput | Prisma.ReferralWhereUniqueInput[];
    disconnect?: Prisma.ReferralWhereUniqueInput | Prisma.ReferralWhereUniqueInput[];
    delete?: Prisma.ReferralWhereUniqueInput | Prisma.ReferralWhereUniqueInput[];
    connect?: Prisma.ReferralWhereUniqueInput | Prisma.ReferralWhereUniqueInput[];
    update?: Prisma.ReferralUpdateWithWhereUniqueWithoutCreatedByInput | Prisma.ReferralUpdateWithWhereUniqueWithoutCreatedByInput[];
    updateMany?: Prisma.ReferralUpdateManyWithWhereWithoutCreatedByInput | Prisma.ReferralUpdateManyWithWhereWithoutCreatedByInput[];
    deleteMany?: Prisma.ReferralScalarWhereInput | Prisma.ReferralScalarWhereInput[];
};
export type NullableStringFieldUpdateOperationsInput = {
    set?: string | null;
};
export type BoolFieldUpdateOperationsInput = {
    set?: boolean;
};
export type NullableIntFieldUpdateOperationsInput = {
    set?: number | null;
    increment?: number;
    decrement?: number;
    multiply?: number;
    divide?: number;
};
export type ReferralCreateWithoutCreatedByInput = {
    organisationName?: string | null;
    category?: string | null;
    website?: string | null;
    phone?: string | null;
    services?: string | null;
    demographics?: string | null;
    availability?: string | null;
    email?: string | null;
    address?: string | null;
    region?: string | null;
    notes?: string | null;
    isActive?: boolean;
    createdAt?: Date | string;
    updatedAt?: Date | string;
};
export type ReferralUncheckedCreateWithoutCreatedByInput = {
    id?: number;
    organisationName?: string | null;
    category?: string | null;
    website?: string | null;
    phone?: string | null;
    services?: string | null;
    demographics?: string | null;
    availability?: string | null;
    email?: string | null;
    address?: string | null;
    region?: string | null;
    notes?: string | null;
    isActive?: boolean;
    createdAt?: Date | string;
    updatedAt?: Date | string;
};
export type ReferralCreateOrConnectWithoutCreatedByInput = {
    where: Prisma.ReferralWhereUniqueInput;
    create: Prisma.XOR<Prisma.ReferralCreateWithoutCreatedByInput, Prisma.ReferralUncheckedCreateWithoutCreatedByInput>;
};
export type ReferralCreateManyCreatedByInputEnvelope = {
    data: Prisma.ReferralCreateManyCreatedByInput | Prisma.ReferralCreateManyCreatedByInput[];
};
export type ReferralUpsertWithWhereUniqueWithoutCreatedByInput = {
    where: Prisma.ReferralWhereUniqueInput;
    update: Prisma.XOR<Prisma.ReferralUpdateWithoutCreatedByInput, Prisma.ReferralUncheckedUpdateWithoutCreatedByInput>;
    create: Prisma.XOR<Prisma.ReferralCreateWithoutCreatedByInput, Prisma.ReferralUncheckedCreateWithoutCreatedByInput>;
};
export type ReferralUpdateWithWhereUniqueWithoutCreatedByInput = {
    where: Prisma.ReferralWhereUniqueInput;
    data: Prisma.XOR<Prisma.ReferralUpdateWithoutCreatedByInput, Prisma.ReferralUncheckedUpdateWithoutCreatedByInput>;
};
export type ReferralUpdateManyWithWhereWithoutCreatedByInput = {
    where: Prisma.ReferralScalarWhereInput;
    data: Prisma.XOR<Prisma.ReferralUpdateManyMutationInput, Prisma.ReferralUncheckedUpdateManyWithoutCreatedByInput>;
};
export type ReferralScalarWhereInput = {
    AND?: Prisma.ReferralScalarWhereInput | Prisma.ReferralScalarWhereInput[];
    OR?: Prisma.ReferralScalarWhereInput[];
    NOT?: Prisma.ReferralScalarWhereInput | Prisma.ReferralScalarWhereInput[];
    id?: Prisma.IntFilter<"Referral"> | number;
    organisationName?: Prisma.StringNullableFilter<"Referral"> | string | null;
    category?: Prisma.StringNullableFilter<"Referral"> | string | null;
    website?: Prisma.StringNullableFilter<"Referral"> | string | null;
    phone?: Prisma.StringNullableFilter<"Referral"> | string | null;
    services?: Prisma.StringNullableFilter<"Referral"> | string | null;
    demographics?: Prisma.StringNullableFilter<"Referral"> | string | null;
    availability?: Prisma.StringNullableFilter<"Referral"> | string | null;
    email?: Prisma.StringNullableFilter<"Referral"> | string | null;
    address?: Prisma.StringNullableFilter<"Referral"> | string | null;
    region?: Prisma.StringNullableFilter<"Referral"> | string | null;
    notes?: Prisma.StringNullableFilter<"Referral"> | string | null;
    isActive?: Prisma.BoolFilter<"Referral"> | boolean;
    createdAt?: Prisma.DateTimeFilter<"Referral"> | Date | string;
    updatedAt?: Prisma.DateTimeFilter<"Referral"> | Date | string;
    createdById?: Prisma.IntNullableFilter<"Referral"> | number | null;
};
export type ReferralCreateManyCreatedByInput = {
    id?: number;
    organisationName?: string | null;
    category?: string | null;
    website?: string | null;
    phone?: string | null;
    services?: string | null;
    demographics?: string | null;
    availability?: string | null;
    email?: string | null;
    address?: string | null;
    region?: string | null;
    notes?: string | null;
    isActive?: boolean;
    createdAt?: Date | string;
    updatedAt?: Date | string;
};
export type ReferralUpdateWithoutCreatedByInput = {
    organisationName?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    category?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    website?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    phone?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    services?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    demographics?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    availability?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    email?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    address?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    region?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    notes?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    isActive?: Prisma.BoolFieldUpdateOperationsInput | boolean;
    createdAt?: Prisma.DateTimeFieldUpdateOperationsInput | Date | string;
    updatedAt?: Prisma.DateTimeFieldUpdateOperationsInput | Date | string;
};
export type ReferralUncheckedUpdateWithoutCreatedByInput = {
    id?: Prisma.IntFieldUpdateOperationsInput | number;
    organisationName?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    category?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    website?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    phone?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    services?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    demographics?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    availability?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    email?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    address?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    region?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    notes?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    isActive?: Prisma.BoolFieldUpdateOperationsInput | boolean;
    createdAt?: Prisma.DateTimeFieldUpdateOperationsInput | Date | string;
    updatedAt?: Prisma.DateTimeFieldUpdateOperationsInput | Date | string;
};
export type ReferralUncheckedUpdateManyWithoutCreatedByInput = {
    id?: Prisma.IntFieldUpdateOperationsInput | number;
    organisationName?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    category?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    website?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    phone?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    services?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    demographics?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    availability?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    email?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    address?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    region?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    notes?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    isActive?: Prisma.BoolFieldUpdateOperationsInput | boolean;
    createdAt?: Prisma.DateTimeFieldUpdateOperationsInput | Date | string;
    updatedAt?: Prisma.DateTimeFieldUpdateOperationsInput | Date | string;
};
export type ReferralSelect<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = runtime.Types.Extensions.GetSelect<{
    id?: boolean;
    organisationName?: boolean;
    category?: boolean;
    website?: boolean;
    phone?: boolean;
    services?: boolean;
    demographics?: boolean;
    availability?: boolean;
    email?: boolean;
    address?: boolean;
    region?: boolean;
    notes?: boolean;
    isActive?: boolean;
    createdAt?: boolean;
    updatedAt?: boolean;
    createdById?: boolean;
    createdBy?: boolean | Prisma.Referral$createdByArgs<ExtArgs>;
}, ExtArgs["result"]["referral"]>;
export type ReferralSelectCreateManyAndReturn<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = runtime.Types.Extensions.GetSelect<{
    id?: boolean;
    organisationName?: boolean;
    category?: boolean;
    website?: boolean;
    phone?: boolean;
    services?: boolean;
    demographics?: boolean;
    availability?: boolean;
    email?: boolean;
    address?: boolean;
    region?: boolean;
    notes?: boolean;
    isActive?: boolean;
    createdAt?: boolean;
    updatedAt?: boolean;
    createdById?: boolean;
    createdBy?: boolean | Prisma.Referral$createdByArgs<ExtArgs>;
}, ExtArgs["result"]["referral"]>;
export type ReferralSelectUpdateManyAndReturn<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = runtime.Types.Extensions.GetSelect<{
    id?: boolean;
    organisationName?: boolean;
    category?: boolean;
    website?: boolean;
    phone?: boolean;
    services?: boolean;
    demographics?: boolean;
    availability?: boolean;
    email?: boolean;
    address?: boolean;
    region?: boolean;
    notes?: boolean;
    isActive?: boolean;
    createdAt?: boolean;
    updatedAt?: boolean;
    createdById?: boolean;
    createdBy?: boolean | Prisma.Referral$createdByArgs<ExtArgs>;
}, ExtArgs["result"]["referral"]>;
export type ReferralSelectScalar = {
    id?: boolean;
    organisationName?: boolean;
    category?: boolean;
    website?: boolean;
    phone?: boolean;
    services?: boolean;
    demographics?: boolean;
    availability?: boolean;
    email?: boolean;
    address?: boolean;
    region?: boolean;
    notes?: boolean;
    isActive?: boolean;
    createdAt?: boolean;
    updatedAt?: boolean;
    createdById?: boolean;
};
export type ReferralOmit<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = runtime.Types.Extensions.GetOmit<"id" | "organisationName" | "category" | "website" | "phone" | "services" | "demographics" | "availability" | "email" | "address" | "region" | "notes" | "isActive" | "createdAt" | "updatedAt" | "createdById", ExtArgs["result"]["referral"]>;
export type ReferralInclude<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    createdBy?: boolean | Prisma.Referral$createdByArgs<ExtArgs>;
};
export type ReferralIncludeCreateManyAndReturn<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    createdBy?: boolean | Prisma.Referral$createdByArgs<ExtArgs>;
};
export type ReferralIncludeUpdateManyAndReturn<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    createdBy?: boolean | Prisma.Referral$createdByArgs<ExtArgs>;
};
export type $ReferralPayload<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    name: "Referral";
    objects: {
        createdBy: Prisma.$StaffUserPayload<ExtArgs> | null;
    };
    scalars: runtime.Types.Extensions.GetPayloadResult<{
        id: number;
        organisationName: string | null;
        category: string | null;
        website: string | null;
        phone: string | null;
        services: string | null;
        demographics: string | null;
        availability: string | null;
        email: string | null;
        address: string | null;
        region: string | null;
        notes: string | null;
        isActive: boolean;
        createdAt: Date;
        updatedAt: Date;
        createdById: number | null;
    }, ExtArgs["result"]["referral"]>;
    composites: {};
};
export type ReferralGetPayload<S extends boolean | null | undefined | ReferralDefaultArgs> = runtime.Types.Result.GetResult<Prisma.$ReferralPayload, S>;
export type ReferralCountArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = Omit<ReferralFindManyArgs, 'select' | 'include' | 'distinct' | 'omit'> & {
    select?: ReferralCountAggregateInputType | true;
};
export interface ReferralDelegate<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs, GlobalOmitOptions = {}> {
    [K: symbol]: {
        types: Prisma.TypeMap<ExtArgs>['model']['Referral'];
        meta: {
            name: 'Referral';
        };
    };
    /**
     * Find zero or one Referral that matches the filter.
     * @param {ReferralFindUniqueArgs} args - Arguments to find a Referral
     * @example
     * // Get one Referral
     * const referral = await prisma.referral.findUnique({
     *   where: {
     *     // ... provide filter here
     *   }
     * })
     */
    findUnique<T extends ReferralFindUniqueArgs>(args: Prisma.SelectSubset<T, ReferralFindUniqueArgs<ExtArgs>>): Prisma.Prisma__ReferralClient<runtime.Types.Result.GetResult<Prisma.$ReferralPayload<ExtArgs>, T, "findUnique", GlobalOmitOptions> | null, null, ExtArgs, GlobalOmitOptions>;
    /**
     * Find one Referral that matches the filter or throw an error with `error.code='P2025'`
     * if no matches were found.
     * @param {ReferralFindUniqueOrThrowArgs} args - Arguments to find a Referral
     * @example
     * // Get one Referral
     * const referral = await prisma.referral.findUniqueOrThrow({
     *   where: {
     *     // ... provide filter here
     *   }
     * })
     */
    findUniqueOrThrow<T extends ReferralFindUniqueOrThrowArgs>(args: Prisma.SelectSubset<T, ReferralFindUniqueOrThrowArgs<ExtArgs>>): Prisma.Prisma__ReferralClient<runtime.Types.Result.GetResult<Prisma.$ReferralPayload<ExtArgs>, T, "findUniqueOrThrow", GlobalOmitOptions>, never, ExtArgs, GlobalOmitOptions>;
    /**
     * Find the first Referral that matches the filter.
     * Note, that providing `undefined` is treated as the value not being there.
     * Read more here: https://pris.ly/d/null-undefined
     * @param {ReferralFindFirstArgs} args - Arguments to find a Referral
     * @example
     * // Get one Referral
     * const referral = await prisma.referral.findFirst({
     *   where: {
     *     // ... provide filter here
     *   }
     * })
     */
    findFirst<T extends ReferralFindFirstArgs>(args?: Prisma.SelectSubset<T, ReferralFindFirstArgs<ExtArgs>>): Prisma.Prisma__ReferralClient<runtime.Types.Result.GetResult<Prisma.$ReferralPayload<ExtArgs>, T, "findFirst", GlobalOmitOptions> | null, null, ExtArgs, GlobalOmitOptions>;
    /**
     * Find the first Referral that matches the filter or
     * throw `PrismaKnownClientError` with `P2025` code if no matches were found.
     * Note, that providing `undefined` is treated as the value not being there.
     * Read more here: https://pris.ly/d/null-undefined
     * @param {ReferralFindFirstOrThrowArgs} args - Arguments to find a Referral
     * @example
     * // Get one Referral
     * const referral = await prisma.referral.findFirstOrThrow({
     *   where: {
     *     // ... provide filter here
     *   }
     * })
     */
    findFirstOrThrow<T extends ReferralFindFirstOrThrowArgs>(args?: Prisma.SelectSubset<T, ReferralFindFirstOrThrowArgs<ExtArgs>>): Prisma.Prisma__ReferralClient<runtime.Types.Result.GetResult<Prisma.$ReferralPayload<ExtArgs>, T, "findFirstOrThrow", GlobalOmitOptions>, never, ExtArgs, GlobalOmitOptions>;
    /**
     * Find zero or more Referrals that matches the filter.
     * Note, that providing `undefined` is treated as the value not being there.
     * Read more here: https://pris.ly/d/null-undefined
     * @param {ReferralFindManyArgs} args - Arguments to filter and select certain fields only.
     * @example
     * // Get all Referrals
     * const referrals = await prisma.referral.findMany()
     *
     * // Get first 10 Referrals
     * const referrals = await prisma.referral.findMany({ take: 10 })
     *
     * // Only select the `id`
     * const referralWithIdOnly = await prisma.referral.findMany({ select: { id: true } })
     *
     */
    findMany<T extends ReferralFindManyArgs>(args?: Prisma.SelectSubset<T, ReferralFindManyArgs<ExtArgs>>): Prisma.PrismaPromise<runtime.Types.Result.GetResult<Prisma.$ReferralPayload<ExtArgs>, T, "findMany", GlobalOmitOptions>>;
    /**
     * Create a Referral.
     * @param {ReferralCreateArgs} args - Arguments to create a Referral.
     * @example
     * // Create one Referral
     * const Referral = await prisma.referral.create({
     *   data: {
     *     // ... data to create a Referral
     *   }
     * })
     *
     */
    create<T extends ReferralCreateArgs>(args: Prisma.SelectSubset<T, ReferralCreateArgs<ExtArgs>>): Prisma.Prisma__ReferralClient<runtime.Types.Result.GetResult<Prisma.$ReferralPayload<ExtArgs>, T, "create", GlobalOmitOptions>, never, ExtArgs, GlobalOmitOptions>;
    /**
     * Create many Referrals.
     * @param {ReferralCreateManyArgs} args - Arguments to create many Referrals.
     * @example
     * // Create many Referrals
     * const referral = await prisma.referral.createMany({
     *   data: [
     *     // ... provide data here
     *   ]
     * })
     *
     */
    createMany<T extends ReferralCreateManyArgs>(args?: Prisma.SelectSubset<T, ReferralCreateManyArgs<ExtArgs>>): Prisma.PrismaPromise<Prisma.BatchPayload>;
    /**
     * Create many Referrals and returns the data saved in the database.
     * @param {ReferralCreateManyAndReturnArgs} args - Arguments to create many Referrals.
     * @example
     * // Create many Referrals
     * const referral = await prisma.referral.createManyAndReturn({
     *   data: [
     *     // ... provide data here
     *   ]
     * })
     *
     * // Create many Referrals and only return the `id`
     * const referralWithIdOnly = await prisma.referral.createManyAndReturn({
     *   select: { id: true },
     *   data: [
     *     // ... provide data here
     *   ]
     * })
     * Note, that providing `undefined` is treated as the value not being there.
     * Read more here: https://pris.ly/d/null-undefined
     *
     */
    createManyAndReturn<T extends ReferralCreateManyAndReturnArgs>(args?: Prisma.SelectSubset<T, ReferralCreateManyAndReturnArgs<ExtArgs>>): Prisma.PrismaPromise<runtime.Types.Result.GetResult<Prisma.$ReferralPayload<ExtArgs>, T, "createManyAndReturn", GlobalOmitOptions>>;
    /**
     * Delete a Referral.
     * @param {ReferralDeleteArgs} args - Arguments to delete one Referral.
     * @example
     * // Delete one Referral
     * const Referral = await prisma.referral.delete({
     *   where: {
     *     // ... filter to delete one Referral
     *   }
     * })
     *
     */
    delete<T extends ReferralDeleteArgs>(args: Prisma.SelectSubset<T, ReferralDeleteArgs<ExtArgs>>): Prisma.Prisma__ReferralClient<runtime.Types.Result.GetResult<Prisma.$ReferralPayload<ExtArgs>, T, "delete", GlobalOmitOptions>, never, ExtArgs, GlobalOmitOptions>;
    /**
     * Update one Referral.
     * @param {ReferralUpdateArgs} args - Arguments to update one Referral.
     * @example
     * // Update one Referral
     * const referral = await prisma.referral.update({
     *   where: {
     *     // ... provide filter here
     *   },
     *   data: {
     *     // ... provide data here
     *   }
     * })
     *
     */
    update<T extends ReferralUpdateArgs>(args: Prisma.SelectSubset<T, ReferralUpdateArgs<ExtArgs>>): Prisma.Prisma__ReferralClient<runtime.Types.Result.GetResult<Prisma.$ReferralPayload<ExtArgs>, T, "update", GlobalOmitOptions>, never, ExtArgs, GlobalOmitOptions>;
    /**
     * Delete zero or more Referrals.
     * @param {ReferralDeleteManyArgs} args - Arguments to filter Referrals to delete.
     * @example
     * // Delete a few Referrals
     * const { count } = await prisma.referral.deleteMany({
     *   where: {
     *     // ... provide filter here
     *   }
     * })
     *
     */
    deleteMany<T extends ReferralDeleteManyArgs>(args?: Prisma.SelectSubset<T, ReferralDeleteManyArgs<ExtArgs>>): Prisma.PrismaPromise<Prisma.BatchPayload>;
    /**
     * Update zero or more Referrals.
     * Note, that providing `undefined` is treated as the value not being there.
     * Read more here: https://pris.ly/d/null-undefined
     * @param {ReferralUpdateManyArgs} args - Arguments to update one or more rows.
     * @example
     * // Update many Referrals
     * const referral = await prisma.referral.updateMany({
     *   where: {
     *     // ... provide filter here
     *   },
     *   data: {
     *     // ... provide data here
     *   }
     * })
     *
     */
    updateMany<T extends ReferralUpdateManyArgs>(args: Prisma.SelectSubset<T, ReferralUpdateManyArgs<ExtArgs>>): Prisma.PrismaPromise<Prisma.BatchPayload>;
    /**
     * Update zero or more Referrals and returns the data updated in the database.
     * @param {ReferralUpdateManyAndReturnArgs} args - Arguments to update many Referrals.
     * @example
     * // Update many Referrals
     * const referral = await prisma.referral.updateManyAndReturn({
     *   where: {
     *     // ... provide filter here
     *   },
     *   data: [
     *     // ... provide data here
     *   ]
     * })
     *
     * // Update zero or more Referrals and only return the `id`
     * const referralWithIdOnly = await prisma.referral.updateManyAndReturn({
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
    updateManyAndReturn<T extends ReferralUpdateManyAndReturnArgs>(args: Prisma.SelectSubset<T, ReferralUpdateManyAndReturnArgs<ExtArgs>>): Prisma.PrismaPromise<runtime.Types.Result.GetResult<Prisma.$ReferralPayload<ExtArgs>, T, "updateManyAndReturn", GlobalOmitOptions>>;
    /**
     * Create or update one Referral.
     * @param {ReferralUpsertArgs} args - Arguments to update or create a Referral.
     * @example
     * // Update or create a Referral
     * const referral = await prisma.referral.upsert({
     *   create: {
     *     // ... data to create a Referral
     *   },
     *   update: {
     *     // ... in case it already exists, update
     *   },
     *   where: {
     *     // ... the filter for the Referral we want to update
     *   }
     * })
     */
    upsert<T extends ReferralUpsertArgs>(args: Prisma.SelectSubset<T, ReferralUpsertArgs<ExtArgs>>): Prisma.Prisma__ReferralClient<runtime.Types.Result.GetResult<Prisma.$ReferralPayload<ExtArgs>, T, "upsert", GlobalOmitOptions>, never, ExtArgs, GlobalOmitOptions>;
    /**
     * Count the number of Referrals.
     * Note, that providing `undefined` is treated as the value not being there.
     * Read more here: https://pris.ly/d/null-undefined
     * @param {ReferralCountArgs} args - Arguments to filter Referrals to count.
     * @example
     * // Count the number of Referrals
     * const count = await prisma.referral.count({
     *   where: {
     *     // ... the filter for the Referrals we want to count
     *   }
     * })
    **/
    count<T extends ReferralCountArgs>(args?: Prisma.Subset<T, ReferralCountArgs>): Prisma.PrismaPromise<T extends runtime.Types.Utils.Record<'select', any> ? T['select'] extends true ? number : Prisma.GetScalarType<T['select'], ReferralCountAggregateOutputType> : number>;
    /**
     * Allows you to perform aggregations operations on a Referral.
     * Note, that providing `undefined` is treated as the value not being there.
     * Read more here: https://pris.ly/d/null-undefined
     * @param {ReferralAggregateArgs} args - Select which aggregations you would like to apply and on what fields.
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
    aggregate<T extends ReferralAggregateArgs>(args: Prisma.Subset<T, ReferralAggregateArgs>): Prisma.PrismaPromise<GetReferralAggregateType<T>>;
    /**
     * Group by Referral.
     * Note, that providing `undefined` is treated as the value not being there.
     * Read more here: https://pris.ly/d/null-undefined
     * @param {ReferralGroupByArgs} args - Group by arguments.
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
    groupBy<T extends ReferralGroupByArgs, HasSelectOrTake extends Prisma.Or<Prisma.Extends<'skip', Prisma.Keys<T>>, Prisma.Extends<'take', Prisma.Keys<T>>>, OrderByArg extends Prisma.True extends HasSelectOrTake ? {
        orderBy: ReferralGroupByArgs['orderBy'];
    } : {
        orderBy?: ReferralGroupByArgs['orderBy'];
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
    }[OrderFields]>(args: Prisma.SubsetIntersection<T, ReferralGroupByArgs, OrderByArg> & InputErrors): {} extends InputErrors ? GetReferralGroupByPayload<T> : Prisma.PrismaPromise<InputErrors>;
    /**
     * Fields of the Referral model
     */
    readonly fields: ReferralFieldRefs;
}
/**
 * The delegate class that acts as a "Promise-like" for Referral.
 * Why is this prefixed with `Prisma__`?
 * Because we want to prevent naming conflicts as mentioned in
 * https://github.com/prisma/prisma-client-js/issues/707
 */
export interface Prisma__ReferralClient<T, Null = never, ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs, GlobalOmitOptions = {}> extends Prisma.PrismaPromise<T> {
    readonly [Symbol.toStringTag]: "PrismaPromise";
    createdBy<T extends Prisma.Referral$createdByArgs<ExtArgs> = {}>(args?: Prisma.Subset<T, Prisma.Referral$createdByArgs<ExtArgs>>): Prisma.Prisma__StaffUserClient<runtime.Types.Result.GetResult<Prisma.$StaffUserPayload<ExtArgs>, T, "findUniqueOrThrow", GlobalOmitOptions> | null, null, ExtArgs, GlobalOmitOptions>;
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
 * Fields of the Referral model
 */
export interface ReferralFieldRefs {
    readonly id: Prisma.FieldRef<"Referral", 'Int'>;
    readonly organisationName: Prisma.FieldRef<"Referral", 'String'>;
    readonly category: Prisma.FieldRef<"Referral", 'String'>;
    readonly website: Prisma.FieldRef<"Referral", 'String'>;
    readonly phone: Prisma.FieldRef<"Referral", 'String'>;
    readonly services: Prisma.FieldRef<"Referral", 'String'>;
    readonly demographics: Prisma.FieldRef<"Referral", 'String'>;
    readonly availability: Prisma.FieldRef<"Referral", 'String'>;
    readonly email: Prisma.FieldRef<"Referral", 'String'>;
    readonly address: Prisma.FieldRef<"Referral", 'String'>;
    readonly region: Prisma.FieldRef<"Referral", 'String'>;
    readonly notes: Prisma.FieldRef<"Referral", 'String'>;
    readonly isActive: Prisma.FieldRef<"Referral", 'Boolean'>;
    readonly createdAt: Prisma.FieldRef<"Referral", 'DateTime'>;
    readonly updatedAt: Prisma.FieldRef<"Referral", 'DateTime'>;
    readonly createdById: Prisma.FieldRef<"Referral", 'Int'>;
}
/**
 * Referral findUnique
 */
export type ReferralFindUniqueArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
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
    /**
     * Filter, which Referral to fetch.
     */
    where: Prisma.ReferralWhereUniqueInput;
};
/**
 * Referral findUniqueOrThrow
 */
export type ReferralFindUniqueOrThrowArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
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
    /**
     * Filter, which Referral to fetch.
     */
    where: Prisma.ReferralWhereUniqueInput;
};
/**
 * Referral findFirst
 */
export type ReferralFindFirstArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
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
    /**
     * Filter, which Referral to fetch.
     */
    where?: Prisma.ReferralWhereInput;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/sorting Sorting Docs}
     *
     * Determine the order of Referrals to fetch.
     */
    orderBy?: Prisma.ReferralOrderByWithRelationInput | Prisma.ReferralOrderByWithRelationInput[];
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/pagination#cursor-based-pagination Cursor Docs}
     *
     * Sets the position for searching for Referrals.
     */
    cursor?: Prisma.ReferralWhereUniqueInput;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/pagination Pagination Docs}
     *
     * Take `±n` Referrals from the position of the cursor.
     */
    take?: number;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/pagination Pagination Docs}
     *
     * Skip the first `n` Referrals.
     */
    skip?: number;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/distinct Distinct Docs}
     *
     * Filter by unique combinations of Referrals.
     */
    distinct?: Prisma.ReferralScalarFieldEnum | Prisma.ReferralScalarFieldEnum[];
};
/**
 * Referral findFirstOrThrow
 */
export type ReferralFindFirstOrThrowArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
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
    /**
     * Filter, which Referral to fetch.
     */
    where?: Prisma.ReferralWhereInput;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/sorting Sorting Docs}
     *
     * Determine the order of Referrals to fetch.
     */
    orderBy?: Prisma.ReferralOrderByWithRelationInput | Prisma.ReferralOrderByWithRelationInput[];
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/pagination#cursor-based-pagination Cursor Docs}
     *
     * Sets the position for searching for Referrals.
     */
    cursor?: Prisma.ReferralWhereUniqueInput;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/pagination Pagination Docs}
     *
     * Take `±n` Referrals from the position of the cursor.
     */
    take?: number;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/pagination Pagination Docs}
     *
     * Skip the first `n` Referrals.
     */
    skip?: number;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/distinct Distinct Docs}
     *
     * Filter by unique combinations of Referrals.
     */
    distinct?: Prisma.ReferralScalarFieldEnum | Prisma.ReferralScalarFieldEnum[];
};
/**
 * Referral findMany
 */
export type ReferralFindManyArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
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
    /**
     * Filter, which Referrals to fetch.
     */
    where?: Prisma.ReferralWhereInput;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/sorting Sorting Docs}
     *
     * Determine the order of Referrals to fetch.
     */
    orderBy?: Prisma.ReferralOrderByWithRelationInput | Prisma.ReferralOrderByWithRelationInput[];
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/pagination#cursor-based-pagination Cursor Docs}
     *
     * Sets the position for listing Referrals.
     */
    cursor?: Prisma.ReferralWhereUniqueInput;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/pagination Pagination Docs}
     *
     * Take `±n` Referrals from the position of the cursor.
     */
    take?: number;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/pagination Pagination Docs}
     *
     * Skip the first `n` Referrals.
     */
    skip?: number;
    distinct?: Prisma.ReferralScalarFieldEnum | Prisma.ReferralScalarFieldEnum[];
};
/**
 * Referral create
 */
export type ReferralCreateArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
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
    /**
     * The data needed to create a Referral.
     */
    data: Prisma.XOR<Prisma.ReferralCreateInput, Prisma.ReferralUncheckedCreateInput>;
};
/**
 * Referral createMany
 */
export type ReferralCreateManyArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    /**
     * The data used to create many Referrals.
     */
    data: Prisma.ReferralCreateManyInput | Prisma.ReferralCreateManyInput[];
};
/**
 * Referral createManyAndReturn
 */
export type ReferralCreateManyAndReturnArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    /**
     * Select specific fields to fetch from the Referral
     */
    select?: Prisma.ReferralSelectCreateManyAndReturn<ExtArgs> | null;
    /**
     * Omit specific fields from the Referral
     */
    omit?: Prisma.ReferralOmit<ExtArgs> | null;
    /**
     * The data used to create many Referrals.
     */
    data: Prisma.ReferralCreateManyInput | Prisma.ReferralCreateManyInput[];
    /**
     * Choose, which related nodes to fetch as well
     */
    include?: Prisma.ReferralIncludeCreateManyAndReturn<ExtArgs> | null;
};
/**
 * Referral update
 */
export type ReferralUpdateArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
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
    /**
     * The data needed to update a Referral.
     */
    data: Prisma.XOR<Prisma.ReferralUpdateInput, Prisma.ReferralUncheckedUpdateInput>;
    /**
     * Choose, which Referral to update.
     */
    where: Prisma.ReferralWhereUniqueInput;
};
/**
 * Referral updateMany
 */
export type ReferralUpdateManyArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    /**
     * The data used to update Referrals.
     */
    data: Prisma.XOR<Prisma.ReferralUpdateManyMutationInput, Prisma.ReferralUncheckedUpdateManyInput>;
    /**
     * Filter which Referrals to update
     */
    where?: Prisma.ReferralWhereInput;
    /**
     * Limit how many Referrals to update.
     */
    limit?: number;
};
/**
 * Referral updateManyAndReturn
 */
export type ReferralUpdateManyAndReturnArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    /**
     * Select specific fields to fetch from the Referral
     */
    select?: Prisma.ReferralSelectUpdateManyAndReturn<ExtArgs> | null;
    /**
     * Omit specific fields from the Referral
     */
    omit?: Prisma.ReferralOmit<ExtArgs> | null;
    /**
     * The data used to update Referrals.
     */
    data: Prisma.XOR<Prisma.ReferralUpdateManyMutationInput, Prisma.ReferralUncheckedUpdateManyInput>;
    /**
     * Filter which Referrals to update
     */
    where?: Prisma.ReferralWhereInput;
    /**
     * Limit how many Referrals to update.
     */
    limit?: number;
    /**
     * Choose, which related nodes to fetch as well
     */
    include?: Prisma.ReferralIncludeUpdateManyAndReturn<ExtArgs> | null;
};
/**
 * Referral upsert
 */
export type ReferralUpsertArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
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
    /**
     * The filter to search for the Referral to update in case it exists.
     */
    where: Prisma.ReferralWhereUniqueInput;
    /**
     * In case the Referral found by the `where` argument doesn't exist, create a new Referral with this data.
     */
    create: Prisma.XOR<Prisma.ReferralCreateInput, Prisma.ReferralUncheckedCreateInput>;
    /**
     * In case the Referral was found with the provided `where` argument, update it with this data.
     */
    update: Prisma.XOR<Prisma.ReferralUpdateInput, Prisma.ReferralUncheckedUpdateInput>;
};
/**
 * Referral delete
 */
export type ReferralDeleteArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
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
    /**
     * Filter which Referral to delete.
     */
    where: Prisma.ReferralWhereUniqueInput;
};
/**
 * Referral deleteMany
 */
export type ReferralDeleteManyArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    /**
     * Filter which Referrals to delete
     */
    where?: Prisma.ReferralWhereInput;
    /**
     * Limit how many Referrals to delete.
     */
    limit?: number;
};
/**
 * Referral.createdBy
 */
export type Referral$createdByArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
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
    where?: Prisma.StaffUserWhereInput;
};
/**
 * Referral without action
 */
export type ReferralDefaultArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
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
};
export {};
//# sourceMappingURL=Referral.d.ts.map