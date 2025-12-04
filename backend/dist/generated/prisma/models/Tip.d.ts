import type * as runtime from "@prisma/client/runtime/library";
import type * as Prisma from "../internal/prismaNamespace";
/**
 * Model Tip
 *
 */
export type TipModel = runtime.Types.Result.DefaultSelection<Prisma.$TipPayload>;
export type AggregateTip = {
    _count: TipCountAggregateOutputType | null;
    _avg: TipAvgAggregateOutputType | null;
    _sum: TipSumAggregateOutputType | null;
    _min: TipMinAggregateOutputType | null;
    _max: TipMaxAggregateOutputType | null;
};
export type TipAvgAggregateOutputType = {
    id: number | null;
    priority: number | null;
    createdById: number | null;
};
export type TipSumAggregateOutputType = {
    id: number | null;
    priority: number | null;
    createdById: number | null;
};
export type TipMinAggregateOutputType = {
    id: number | null;
    title: string | null;
    body: string | null;
    category: string | null;
    audience: string | null;
    ctaLabel: string | null;
    ctaUrl: string | null;
    priority: number | null;
    isActive: boolean | null;
    publishAt: Date | null;
    expiresAt: Date | null;
    createdAt: Date | null;
    updatedAt: Date | null;
    createdById: number | null;
};
export type TipMaxAggregateOutputType = {
    id: number | null;
    title: string | null;
    body: string | null;
    category: string | null;
    audience: string | null;
    ctaLabel: string | null;
    ctaUrl: string | null;
    priority: number | null;
    isActive: boolean | null;
    publishAt: Date | null;
    expiresAt: Date | null;
    createdAt: Date | null;
    updatedAt: Date | null;
    createdById: number | null;
};
export type TipCountAggregateOutputType = {
    id: number;
    title: number;
    body: number;
    category: number;
    audience: number;
    ctaLabel: number;
    ctaUrl: number;
    priority: number;
    isActive: number;
    publishAt: number;
    expiresAt: number;
    createdAt: number;
    updatedAt: number;
    createdById: number;
    _all: number;
};
export type TipAvgAggregateInputType = {
    id?: true;
    priority?: true;
    createdById?: true;
};
export type TipSumAggregateInputType = {
    id?: true;
    priority?: true;
    createdById?: true;
};
export type TipMinAggregateInputType = {
    id?: true;
    title?: true;
    body?: true;
    category?: true;
    audience?: true;
    ctaLabel?: true;
    ctaUrl?: true;
    priority?: true;
    isActive?: true;
    publishAt?: true;
    expiresAt?: true;
    createdAt?: true;
    updatedAt?: true;
    createdById?: true;
};
export type TipMaxAggregateInputType = {
    id?: true;
    title?: true;
    body?: true;
    category?: true;
    audience?: true;
    ctaLabel?: true;
    ctaUrl?: true;
    priority?: true;
    isActive?: true;
    publishAt?: true;
    expiresAt?: true;
    createdAt?: true;
    updatedAt?: true;
    createdById?: true;
};
export type TipCountAggregateInputType = {
    id?: true;
    title?: true;
    body?: true;
    category?: true;
    audience?: true;
    ctaLabel?: true;
    ctaUrl?: true;
    priority?: true;
    isActive?: true;
    publishAt?: true;
    expiresAt?: true;
    createdAt?: true;
    updatedAt?: true;
    createdById?: true;
    _all?: true;
};
export type TipAggregateArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    /**
     * Filter which Tip to aggregate.
     */
    where?: Prisma.TipWhereInput;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/sorting Sorting Docs}
     *
     * Determine the order of Tips to fetch.
     */
    orderBy?: Prisma.TipOrderByWithRelationInput | Prisma.TipOrderByWithRelationInput[];
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/pagination#cursor-based-pagination Cursor Docs}
     *
     * Sets the start position
     */
    cursor?: Prisma.TipWhereUniqueInput;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/pagination Pagination Docs}
     *
     * Take `±n` Tips from the position of the cursor.
     */
    take?: number;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/pagination Pagination Docs}
     *
     * Skip the first `n` Tips.
     */
    skip?: number;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/aggregations Aggregation Docs}
     *
     * Count returned Tips
    **/
    _count?: true | TipCountAggregateInputType;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/aggregations Aggregation Docs}
     *
     * Select which fields to average
    **/
    _avg?: TipAvgAggregateInputType;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/aggregations Aggregation Docs}
     *
     * Select which fields to sum
    **/
    _sum?: TipSumAggregateInputType;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/aggregations Aggregation Docs}
     *
     * Select which fields to find the minimum value
    **/
    _min?: TipMinAggregateInputType;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/aggregations Aggregation Docs}
     *
     * Select which fields to find the maximum value
    **/
    _max?: TipMaxAggregateInputType;
};
export type GetTipAggregateType<T extends TipAggregateArgs> = {
    [P in keyof T & keyof AggregateTip]: P extends '_count' | 'count' ? T[P] extends true ? number : Prisma.GetScalarType<T[P], AggregateTip[P]> : Prisma.GetScalarType<T[P], AggregateTip[P]>;
};
export type TipGroupByArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    where?: Prisma.TipWhereInput;
    orderBy?: Prisma.TipOrderByWithAggregationInput | Prisma.TipOrderByWithAggregationInput[];
    by: Prisma.TipScalarFieldEnum[] | Prisma.TipScalarFieldEnum;
    having?: Prisma.TipScalarWhereWithAggregatesInput;
    take?: number;
    skip?: number;
    _count?: TipCountAggregateInputType | true;
    _avg?: TipAvgAggregateInputType;
    _sum?: TipSumAggregateInputType;
    _min?: TipMinAggregateInputType;
    _max?: TipMaxAggregateInputType;
};
export type TipGroupByOutputType = {
    id: number;
    title: string;
    body: string;
    category: string | null;
    audience: string | null;
    ctaLabel: string | null;
    ctaUrl: string | null;
    priority: number;
    isActive: boolean;
    publishAt: Date | null;
    expiresAt: Date | null;
    createdAt: Date;
    updatedAt: Date;
    createdById: number | null;
    _count: TipCountAggregateOutputType | null;
    _avg: TipAvgAggregateOutputType | null;
    _sum: TipSumAggregateOutputType | null;
    _min: TipMinAggregateOutputType | null;
    _max: TipMaxAggregateOutputType | null;
};
type GetTipGroupByPayload<T extends TipGroupByArgs> = Prisma.PrismaPromise<Array<Prisma.PickEnumerable<TipGroupByOutputType, T['by']> & {
    [P in ((keyof T) & (keyof TipGroupByOutputType))]: P extends '_count' ? T[P] extends boolean ? number : Prisma.GetScalarType<T[P], TipGroupByOutputType[P]> : Prisma.GetScalarType<T[P], TipGroupByOutputType[P]>;
}>>;
export type TipWhereInput = {
    AND?: Prisma.TipWhereInput | Prisma.TipWhereInput[];
    OR?: Prisma.TipWhereInput[];
    NOT?: Prisma.TipWhereInput | Prisma.TipWhereInput[];
    id?: Prisma.IntFilter<"Tip"> | number;
    title?: Prisma.StringFilter<"Tip"> | string;
    body?: Prisma.StringFilter<"Tip"> | string;
    category?: Prisma.StringNullableFilter<"Tip"> | string | null;
    audience?: Prisma.StringNullableFilter<"Tip"> | string | null;
    ctaLabel?: Prisma.StringNullableFilter<"Tip"> | string | null;
    ctaUrl?: Prisma.StringNullableFilter<"Tip"> | string | null;
    priority?: Prisma.IntFilter<"Tip"> | number;
    isActive?: Prisma.BoolFilter<"Tip"> | boolean;
    publishAt?: Prisma.DateTimeNullableFilter<"Tip"> | Date | string | null;
    expiresAt?: Prisma.DateTimeNullableFilter<"Tip"> | Date | string | null;
    createdAt?: Prisma.DateTimeFilter<"Tip"> | Date | string;
    updatedAt?: Prisma.DateTimeFilter<"Tip"> | Date | string;
    createdById?: Prisma.IntNullableFilter<"Tip"> | number | null;
    createdBy?: Prisma.XOR<Prisma.StaffUserNullableScalarRelationFilter, Prisma.StaffUserWhereInput> | null;
};
export type TipOrderByWithRelationInput = {
    id?: Prisma.SortOrder;
    title?: Prisma.SortOrder;
    body?: Prisma.SortOrder;
    category?: Prisma.SortOrderInput | Prisma.SortOrder;
    audience?: Prisma.SortOrderInput | Prisma.SortOrder;
    ctaLabel?: Prisma.SortOrderInput | Prisma.SortOrder;
    ctaUrl?: Prisma.SortOrderInput | Prisma.SortOrder;
    priority?: Prisma.SortOrder;
    isActive?: Prisma.SortOrder;
    publishAt?: Prisma.SortOrderInput | Prisma.SortOrder;
    expiresAt?: Prisma.SortOrderInput | Prisma.SortOrder;
    createdAt?: Prisma.SortOrder;
    updatedAt?: Prisma.SortOrder;
    createdById?: Prisma.SortOrderInput | Prisma.SortOrder;
    createdBy?: Prisma.StaffUserOrderByWithRelationInput;
};
export type TipWhereUniqueInput = Prisma.AtLeast<{
    id?: number;
    AND?: Prisma.TipWhereInput | Prisma.TipWhereInput[];
    OR?: Prisma.TipWhereInput[];
    NOT?: Prisma.TipWhereInput | Prisma.TipWhereInput[];
    title?: Prisma.StringFilter<"Tip"> | string;
    body?: Prisma.StringFilter<"Tip"> | string;
    category?: Prisma.StringNullableFilter<"Tip"> | string | null;
    audience?: Prisma.StringNullableFilter<"Tip"> | string | null;
    ctaLabel?: Prisma.StringNullableFilter<"Tip"> | string | null;
    ctaUrl?: Prisma.StringNullableFilter<"Tip"> | string | null;
    priority?: Prisma.IntFilter<"Tip"> | number;
    isActive?: Prisma.BoolFilter<"Tip"> | boolean;
    publishAt?: Prisma.DateTimeNullableFilter<"Tip"> | Date | string | null;
    expiresAt?: Prisma.DateTimeNullableFilter<"Tip"> | Date | string | null;
    createdAt?: Prisma.DateTimeFilter<"Tip"> | Date | string;
    updatedAt?: Prisma.DateTimeFilter<"Tip"> | Date | string;
    createdById?: Prisma.IntNullableFilter<"Tip"> | number | null;
    createdBy?: Prisma.XOR<Prisma.StaffUserNullableScalarRelationFilter, Prisma.StaffUserWhereInput> | null;
}, "id">;
export type TipOrderByWithAggregationInput = {
    id?: Prisma.SortOrder;
    title?: Prisma.SortOrder;
    body?: Prisma.SortOrder;
    category?: Prisma.SortOrderInput | Prisma.SortOrder;
    audience?: Prisma.SortOrderInput | Prisma.SortOrder;
    ctaLabel?: Prisma.SortOrderInput | Prisma.SortOrder;
    ctaUrl?: Prisma.SortOrderInput | Prisma.SortOrder;
    priority?: Prisma.SortOrder;
    isActive?: Prisma.SortOrder;
    publishAt?: Prisma.SortOrderInput | Prisma.SortOrder;
    expiresAt?: Prisma.SortOrderInput | Prisma.SortOrder;
    createdAt?: Prisma.SortOrder;
    updatedAt?: Prisma.SortOrder;
    createdById?: Prisma.SortOrderInput | Prisma.SortOrder;
    _count?: Prisma.TipCountOrderByAggregateInput;
    _avg?: Prisma.TipAvgOrderByAggregateInput;
    _max?: Prisma.TipMaxOrderByAggregateInput;
    _min?: Prisma.TipMinOrderByAggregateInput;
    _sum?: Prisma.TipSumOrderByAggregateInput;
};
export type TipScalarWhereWithAggregatesInput = {
    AND?: Prisma.TipScalarWhereWithAggregatesInput | Prisma.TipScalarWhereWithAggregatesInput[];
    OR?: Prisma.TipScalarWhereWithAggregatesInput[];
    NOT?: Prisma.TipScalarWhereWithAggregatesInput | Prisma.TipScalarWhereWithAggregatesInput[];
    id?: Prisma.IntWithAggregatesFilter<"Tip"> | number;
    title?: Prisma.StringWithAggregatesFilter<"Tip"> | string;
    body?: Prisma.StringWithAggregatesFilter<"Tip"> | string;
    category?: Prisma.StringNullableWithAggregatesFilter<"Tip"> | string | null;
    audience?: Prisma.StringNullableWithAggregatesFilter<"Tip"> | string | null;
    ctaLabel?: Prisma.StringNullableWithAggregatesFilter<"Tip"> | string | null;
    ctaUrl?: Prisma.StringNullableWithAggregatesFilter<"Tip"> | string | null;
    priority?: Prisma.IntWithAggregatesFilter<"Tip"> | number;
    isActive?: Prisma.BoolWithAggregatesFilter<"Tip"> | boolean;
    publishAt?: Prisma.DateTimeNullableWithAggregatesFilter<"Tip"> | Date | string | null;
    expiresAt?: Prisma.DateTimeNullableWithAggregatesFilter<"Tip"> | Date | string | null;
    createdAt?: Prisma.DateTimeWithAggregatesFilter<"Tip"> | Date | string;
    updatedAt?: Prisma.DateTimeWithAggregatesFilter<"Tip"> | Date | string;
    createdById?: Prisma.IntNullableWithAggregatesFilter<"Tip"> | number | null;
};
export type TipCreateInput = {
    title: string;
    body: string;
    category?: string | null;
    audience?: string | null;
    ctaLabel?: string | null;
    ctaUrl?: string | null;
    priority?: number;
    isActive?: boolean;
    publishAt?: Date | string | null;
    expiresAt?: Date | string | null;
    createdAt?: Date | string;
    updatedAt?: Date | string;
    createdBy?: Prisma.StaffUserCreateNestedOneWithoutTipsInput;
};
export type TipUncheckedCreateInput = {
    id?: number;
    title: string;
    body: string;
    category?: string | null;
    audience?: string | null;
    ctaLabel?: string | null;
    ctaUrl?: string | null;
    priority?: number;
    isActive?: boolean;
    publishAt?: Date | string | null;
    expiresAt?: Date | string | null;
    createdAt?: Date | string;
    updatedAt?: Date | string;
    createdById?: number | null;
};
export type TipUpdateInput = {
    title?: Prisma.StringFieldUpdateOperationsInput | string;
    body?: Prisma.StringFieldUpdateOperationsInput | string;
    category?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    audience?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    ctaLabel?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    ctaUrl?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    priority?: Prisma.IntFieldUpdateOperationsInput | number;
    isActive?: Prisma.BoolFieldUpdateOperationsInput | boolean;
    publishAt?: Prisma.NullableDateTimeFieldUpdateOperationsInput | Date | string | null;
    expiresAt?: Prisma.NullableDateTimeFieldUpdateOperationsInput | Date | string | null;
    createdAt?: Prisma.DateTimeFieldUpdateOperationsInput | Date | string;
    updatedAt?: Prisma.DateTimeFieldUpdateOperationsInput | Date | string;
    createdBy?: Prisma.StaffUserUpdateOneWithoutTipsNestedInput;
};
export type TipUncheckedUpdateInput = {
    id?: Prisma.IntFieldUpdateOperationsInput | number;
    title?: Prisma.StringFieldUpdateOperationsInput | string;
    body?: Prisma.StringFieldUpdateOperationsInput | string;
    category?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    audience?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    ctaLabel?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    ctaUrl?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    priority?: Prisma.IntFieldUpdateOperationsInput | number;
    isActive?: Prisma.BoolFieldUpdateOperationsInput | boolean;
    publishAt?: Prisma.NullableDateTimeFieldUpdateOperationsInput | Date | string | null;
    expiresAt?: Prisma.NullableDateTimeFieldUpdateOperationsInput | Date | string | null;
    createdAt?: Prisma.DateTimeFieldUpdateOperationsInput | Date | string;
    updatedAt?: Prisma.DateTimeFieldUpdateOperationsInput | Date | string;
    createdById?: Prisma.NullableIntFieldUpdateOperationsInput | number | null;
};
export type TipCreateManyInput = {
    id?: number;
    title: string;
    body: string;
    category?: string | null;
    audience?: string | null;
    ctaLabel?: string | null;
    ctaUrl?: string | null;
    priority?: number;
    isActive?: boolean;
    publishAt?: Date | string | null;
    expiresAt?: Date | string | null;
    createdAt?: Date | string;
    updatedAt?: Date | string;
    createdById?: number | null;
};
export type TipUpdateManyMutationInput = {
    title?: Prisma.StringFieldUpdateOperationsInput | string;
    body?: Prisma.StringFieldUpdateOperationsInput | string;
    category?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    audience?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    ctaLabel?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    ctaUrl?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    priority?: Prisma.IntFieldUpdateOperationsInput | number;
    isActive?: Prisma.BoolFieldUpdateOperationsInput | boolean;
    publishAt?: Prisma.NullableDateTimeFieldUpdateOperationsInput | Date | string | null;
    expiresAt?: Prisma.NullableDateTimeFieldUpdateOperationsInput | Date | string | null;
    createdAt?: Prisma.DateTimeFieldUpdateOperationsInput | Date | string;
    updatedAt?: Prisma.DateTimeFieldUpdateOperationsInput | Date | string;
};
export type TipUncheckedUpdateManyInput = {
    id?: Prisma.IntFieldUpdateOperationsInput | number;
    title?: Prisma.StringFieldUpdateOperationsInput | string;
    body?: Prisma.StringFieldUpdateOperationsInput | string;
    category?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    audience?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    ctaLabel?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    ctaUrl?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    priority?: Prisma.IntFieldUpdateOperationsInput | number;
    isActive?: Prisma.BoolFieldUpdateOperationsInput | boolean;
    publishAt?: Prisma.NullableDateTimeFieldUpdateOperationsInput | Date | string | null;
    expiresAt?: Prisma.NullableDateTimeFieldUpdateOperationsInput | Date | string | null;
    createdAt?: Prisma.DateTimeFieldUpdateOperationsInput | Date | string;
    updatedAt?: Prisma.DateTimeFieldUpdateOperationsInput | Date | string;
    createdById?: Prisma.NullableIntFieldUpdateOperationsInput | number | null;
};
export type TipListRelationFilter = {
    every?: Prisma.TipWhereInput;
    some?: Prisma.TipWhereInput;
    none?: Prisma.TipWhereInput;
};
export type TipOrderByRelationAggregateInput = {
    _count?: Prisma.SortOrder;
};
export type TipCountOrderByAggregateInput = {
    id?: Prisma.SortOrder;
    title?: Prisma.SortOrder;
    body?: Prisma.SortOrder;
    category?: Prisma.SortOrder;
    audience?: Prisma.SortOrder;
    ctaLabel?: Prisma.SortOrder;
    ctaUrl?: Prisma.SortOrder;
    priority?: Prisma.SortOrder;
    isActive?: Prisma.SortOrder;
    publishAt?: Prisma.SortOrder;
    expiresAt?: Prisma.SortOrder;
    createdAt?: Prisma.SortOrder;
    updatedAt?: Prisma.SortOrder;
    createdById?: Prisma.SortOrder;
};
export type TipAvgOrderByAggregateInput = {
    id?: Prisma.SortOrder;
    priority?: Prisma.SortOrder;
    createdById?: Prisma.SortOrder;
};
export type TipMaxOrderByAggregateInput = {
    id?: Prisma.SortOrder;
    title?: Prisma.SortOrder;
    body?: Prisma.SortOrder;
    category?: Prisma.SortOrder;
    audience?: Prisma.SortOrder;
    ctaLabel?: Prisma.SortOrder;
    ctaUrl?: Prisma.SortOrder;
    priority?: Prisma.SortOrder;
    isActive?: Prisma.SortOrder;
    publishAt?: Prisma.SortOrder;
    expiresAt?: Prisma.SortOrder;
    createdAt?: Prisma.SortOrder;
    updatedAt?: Prisma.SortOrder;
    createdById?: Prisma.SortOrder;
};
export type TipMinOrderByAggregateInput = {
    id?: Prisma.SortOrder;
    title?: Prisma.SortOrder;
    body?: Prisma.SortOrder;
    category?: Prisma.SortOrder;
    audience?: Prisma.SortOrder;
    ctaLabel?: Prisma.SortOrder;
    ctaUrl?: Prisma.SortOrder;
    priority?: Prisma.SortOrder;
    isActive?: Prisma.SortOrder;
    publishAt?: Prisma.SortOrder;
    expiresAt?: Prisma.SortOrder;
    createdAt?: Prisma.SortOrder;
    updatedAt?: Prisma.SortOrder;
    createdById?: Prisma.SortOrder;
};
export type TipSumOrderByAggregateInput = {
    id?: Prisma.SortOrder;
    priority?: Prisma.SortOrder;
    createdById?: Prisma.SortOrder;
};
export type TipCreateNestedManyWithoutCreatedByInput = {
    create?: Prisma.XOR<Prisma.TipCreateWithoutCreatedByInput, Prisma.TipUncheckedCreateWithoutCreatedByInput> | Prisma.TipCreateWithoutCreatedByInput[] | Prisma.TipUncheckedCreateWithoutCreatedByInput[];
    connectOrCreate?: Prisma.TipCreateOrConnectWithoutCreatedByInput | Prisma.TipCreateOrConnectWithoutCreatedByInput[];
    createMany?: Prisma.TipCreateManyCreatedByInputEnvelope;
    connect?: Prisma.TipWhereUniqueInput | Prisma.TipWhereUniqueInput[];
};
export type TipUncheckedCreateNestedManyWithoutCreatedByInput = {
    create?: Prisma.XOR<Prisma.TipCreateWithoutCreatedByInput, Prisma.TipUncheckedCreateWithoutCreatedByInput> | Prisma.TipCreateWithoutCreatedByInput[] | Prisma.TipUncheckedCreateWithoutCreatedByInput[];
    connectOrCreate?: Prisma.TipCreateOrConnectWithoutCreatedByInput | Prisma.TipCreateOrConnectWithoutCreatedByInput[];
    createMany?: Prisma.TipCreateManyCreatedByInputEnvelope;
    connect?: Prisma.TipWhereUniqueInput | Prisma.TipWhereUniqueInput[];
};
export type TipUpdateManyWithoutCreatedByNestedInput = {
    create?: Prisma.XOR<Prisma.TipCreateWithoutCreatedByInput, Prisma.TipUncheckedCreateWithoutCreatedByInput> | Prisma.TipCreateWithoutCreatedByInput[] | Prisma.TipUncheckedCreateWithoutCreatedByInput[];
    connectOrCreate?: Prisma.TipCreateOrConnectWithoutCreatedByInput | Prisma.TipCreateOrConnectWithoutCreatedByInput[];
    upsert?: Prisma.TipUpsertWithWhereUniqueWithoutCreatedByInput | Prisma.TipUpsertWithWhereUniqueWithoutCreatedByInput[];
    createMany?: Prisma.TipCreateManyCreatedByInputEnvelope;
    set?: Prisma.TipWhereUniqueInput | Prisma.TipWhereUniqueInput[];
    disconnect?: Prisma.TipWhereUniqueInput | Prisma.TipWhereUniqueInput[];
    delete?: Prisma.TipWhereUniqueInput | Prisma.TipWhereUniqueInput[];
    connect?: Prisma.TipWhereUniqueInput | Prisma.TipWhereUniqueInput[];
    update?: Prisma.TipUpdateWithWhereUniqueWithoutCreatedByInput | Prisma.TipUpdateWithWhereUniqueWithoutCreatedByInput[];
    updateMany?: Prisma.TipUpdateManyWithWhereWithoutCreatedByInput | Prisma.TipUpdateManyWithWhereWithoutCreatedByInput[];
    deleteMany?: Prisma.TipScalarWhereInput | Prisma.TipScalarWhereInput[];
};
export type TipUncheckedUpdateManyWithoutCreatedByNestedInput = {
    create?: Prisma.XOR<Prisma.TipCreateWithoutCreatedByInput, Prisma.TipUncheckedCreateWithoutCreatedByInput> | Prisma.TipCreateWithoutCreatedByInput[] | Prisma.TipUncheckedCreateWithoutCreatedByInput[];
    connectOrCreate?: Prisma.TipCreateOrConnectWithoutCreatedByInput | Prisma.TipCreateOrConnectWithoutCreatedByInput[];
    upsert?: Prisma.TipUpsertWithWhereUniqueWithoutCreatedByInput | Prisma.TipUpsertWithWhereUniqueWithoutCreatedByInput[];
    createMany?: Prisma.TipCreateManyCreatedByInputEnvelope;
    set?: Prisma.TipWhereUniqueInput | Prisma.TipWhereUniqueInput[];
    disconnect?: Prisma.TipWhereUniqueInput | Prisma.TipWhereUniqueInput[];
    delete?: Prisma.TipWhereUniqueInput | Prisma.TipWhereUniqueInput[];
    connect?: Prisma.TipWhereUniqueInput | Prisma.TipWhereUniqueInput[];
    update?: Prisma.TipUpdateWithWhereUniqueWithoutCreatedByInput | Prisma.TipUpdateWithWhereUniqueWithoutCreatedByInput[];
    updateMany?: Prisma.TipUpdateManyWithWhereWithoutCreatedByInput | Prisma.TipUpdateManyWithWhereWithoutCreatedByInput[];
    deleteMany?: Prisma.TipScalarWhereInput | Prisma.TipScalarWhereInput[];
};
export type NullableDateTimeFieldUpdateOperationsInput = {
    set?: Date | string | null;
};
export type TipCreateWithoutCreatedByInput = {
    title: string;
    body: string;
    category?: string | null;
    audience?: string | null;
    ctaLabel?: string | null;
    ctaUrl?: string | null;
    priority?: number;
    isActive?: boolean;
    publishAt?: Date | string | null;
    expiresAt?: Date | string | null;
    createdAt?: Date | string;
    updatedAt?: Date | string;
};
export type TipUncheckedCreateWithoutCreatedByInput = {
    id?: number;
    title: string;
    body: string;
    category?: string | null;
    audience?: string | null;
    ctaLabel?: string | null;
    ctaUrl?: string | null;
    priority?: number;
    isActive?: boolean;
    publishAt?: Date | string | null;
    expiresAt?: Date | string | null;
    createdAt?: Date | string;
    updatedAt?: Date | string;
};
export type TipCreateOrConnectWithoutCreatedByInput = {
    where: Prisma.TipWhereUniqueInput;
    create: Prisma.XOR<Prisma.TipCreateWithoutCreatedByInput, Prisma.TipUncheckedCreateWithoutCreatedByInput>;
};
export type TipCreateManyCreatedByInputEnvelope = {
    data: Prisma.TipCreateManyCreatedByInput | Prisma.TipCreateManyCreatedByInput[];
};
export type TipUpsertWithWhereUniqueWithoutCreatedByInput = {
    where: Prisma.TipWhereUniqueInput;
    update: Prisma.XOR<Prisma.TipUpdateWithoutCreatedByInput, Prisma.TipUncheckedUpdateWithoutCreatedByInput>;
    create: Prisma.XOR<Prisma.TipCreateWithoutCreatedByInput, Prisma.TipUncheckedCreateWithoutCreatedByInput>;
};
export type TipUpdateWithWhereUniqueWithoutCreatedByInput = {
    where: Prisma.TipWhereUniqueInput;
    data: Prisma.XOR<Prisma.TipUpdateWithoutCreatedByInput, Prisma.TipUncheckedUpdateWithoutCreatedByInput>;
};
export type TipUpdateManyWithWhereWithoutCreatedByInput = {
    where: Prisma.TipScalarWhereInput;
    data: Prisma.XOR<Prisma.TipUpdateManyMutationInput, Prisma.TipUncheckedUpdateManyWithoutCreatedByInput>;
};
export type TipScalarWhereInput = {
    AND?: Prisma.TipScalarWhereInput | Prisma.TipScalarWhereInput[];
    OR?: Prisma.TipScalarWhereInput[];
    NOT?: Prisma.TipScalarWhereInput | Prisma.TipScalarWhereInput[];
    id?: Prisma.IntFilter<"Tip"> | number;
    title?: Prisma.StringFilter<"Tip"> | string;
    body?: Prisma.StringFilter<"Tip"> | string;
    category?: Prisma.StringNullableFilter<"Tip"> | string | null;
    audience?: Prisma.StringNullableFilter<"Tip"> | string | null;
    ctaLabel?: Prisma.StringNullableFilter<"Tip"> | string | null;
    ctaUrl?: Prisma.StringNullableFilter<"Tip"> | string | null;
    priority?: Prisma.IntFilter<"Tip"> | number;
    isActive?: Prisma.BoolFilter<"Tip"> | boolean;
    publishAt?: Prisma.DateTimeNullableFilter<"Tip"> | Date | string | null;
    expiresAt?: Prisma.DateTimeNullableFilter<"Tip"> | Date | string | null;
    createdAt?: Prisma.DateTimeFilter<"Tip"> | Date | string;
    updatedAt?: Prisma.DateTimeFilter<"Tip"> | Date | string;
    createdById?: Prisma.IntNullableFilter<"Tip"> | number | null;
};
export type TipCreateManyCreatedByInput = {
    id?: number;
    title: string;
    body: string;
    category?: string | null;
    audience?: string | null;
    ctaLabel?: string | null;
    ctaUrl?: string | null;
    priority?: number;
    isActive?: boolean;
    publishAt?: Date | string | null;
    expiresAt?: Date | string | null;
    createdAt?: Date | string;
    updatedAt?: Date | string;
};
export type TipUpdateWithoutCreatedByInput = {
    title?: Prisma.StringFieldUpdateOperationsInput | string;
    body?: Prisma.StringFieldUpdateOperationsInput | string;
    category?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    audience?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    ctaLabel?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    ctaUrl?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    priority?: Prisma.IntFieldUpdateOperationsInput | number;
    isActive?: Prisma.BoolFieldUpdateOperationsInput | boolean;
    publishAt?: Prisma.NullableDateTimeFieldUpdateOperationsInput | Date | string | null;
    expiresAt?: Prisma.NullableDateTimeFieldUpdateOperationsInput | Date | string | null;
    createdAt?: Prisma.DateTimeFieldUpdateOperationsInput | Date | string;
    updatedAt?: Prisma.DateTimeFieldUpdateOperationsInput | Date | string;
};
export type TipUncheckedUpdateWithoutCreatedByInput = {
    id?: Prisma.IntFieldUpdateOperationsInput | number;
    title?: Prisma.StringFieldUpdateOperationsInput | string;
    body?: Prisma.StringFieldUpdateOperationsInput | string;
    category?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    audience?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    ctaLabel?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    ctaUrl?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    priority?: Prisma.IntFieldUpdateOperationsInput | number;
    isActive?: Prisma.BoolFieldUpdateOperationsInput | boolean;
    publishAt?: Prisma.NullableDateTimeFieldUpdateOperationsInput | Date | string | null;
    expiresAt?: Prisma.NullableDateTimeFieldUpdateOperationsInput | Date | string | null;
    createdAt?: Prisma.DateTimeFieldUpdateOperationsInput | Date | string;
    updatedAt?: Prisma.DateTimeFieldUpdateOperationsInput | Date | string;
};
export type TipUncheckedUpdateManyWithoutCreatedByInput = {
    id?: Prisma.IntFieldUpdateOperationsInput | number;
    title?: Prisma.StringFieldUpdateOperationsInput | string;
    body?: Prisma.StringFieldUpdateOperationsInput | string;
    category?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    audience?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    ctaLabel?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    ctaUrl?: Prisma.NullableStringFieldUpdateOperationsInput | string | null;
    priority?: Prisma.IntFieldUpdateOperationsInput | number;
    isActive?: Prisma.BoolFieldUpdateOperationsInput | boolean;
    publishAt?: Prisma.NullableDateTimeFieldUpdateOperationsInput | Date | string | null;
    expiresAt?: Prisma.NullableDateTimeFieldUpdateOperationsInput | Date | string | null;
    createdAt?: Prisma.DateTimeFieldUpdateOperationsInput | Date | string;
    updatedAt?: Prisma.DateTimeFieldUpdateOperationsInput | Date | string;
};
export type TipSelect<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = runtime.Types.Extensions.GetSelect<{
    id?: boolean;
    title?: boolean;
    body?: boolean;
    category?: boolean;
    audience?: boolean;
    ctaLabel?: boolean;
    ctaUrl?: boolean;
    priority?: boolean;
    isActive?: boolean;
    publishAt?: boolean;
    expiresAt?: boolean;
    createdAt?: boolean;
    updatedAt?: boolean;
    createdById?: boolean;
    createdBy?: boolean | Prisma.Tip$createdByArgs<ExtArgs>;
}, ExtArgs["result"]["tip"]>;
export type TipSelectCreateManyAndReturn<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = runtime.Types.Extensions.GetSelect<{
    id?: boolean;
    title?: boolean;
    body?: boolean;
    category?: boolean;
    audience?: boolean;
    ctaLabel?: boolean;
    ctaUrl?: boolean;
    priority?: boolean;
    isActive?: boolean;
    publishAt?: boolean;
    expiresAt?: boolean;
    createdAt?: boolean;
    updatedAt?: boolean;
    createdById?: boolean;
    createdBy?: boolean | Prisma.Tip$createdByArgs<ExtArgs>;
}, ExtArgs["result"]["tip"]>;
export type TipSelectUpdateManyAndReturn<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = runtime.Types.Extensions.GetSelect<{
    id?: boolean;
    title?: boolean;
    body?: boolean;
    category?: boolean;
    audience?: boolean;
    ctaLabel?: boolean;
    ctaUrl?: boolean;
    priority?: boolean;
    isActive?: boolean;
    publishAt?: boolean;
    expiresAt?: boolean;
    createdAt?: boolean;
    updatedAt?: boolean;
    createdById?: boolean;
    createdBy?: boolean | Prisma.Tip$createdByArgs<ExtArgs>;
}, ExtArgs["result"]["tip"]>;
export type TipSelectScalar = {
    id?: boolean;
    title?: boolean;
    body?: boolean;
    category?: boolean;
    audience?: boolean;
    ctaLabel?: boolean;
    ctaUrl?: boolean;
    priority?: boolean;
    isActive?: boolean;
    publishAt?: boolean;
    expiresAt?: boolean;
    createdAt?: boolean;
    updatedAt?: boolean;
    createdById?: boolean;
};
export type TipOmit<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = runtime.Types.Extensions.GetOmit<"id" | "title" | "body" | "category" | "audience" | "ctaLabel" | "ctaUrl" | "priority" | "isActive" | "publishAt" | "expiresAt" | "createdAt" | "updatedAt" | "createdById", ExtArgs["result"]["tip"]>;
export type TipInclude<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    createdBy?: boolean | Prisma.Tip$createdByArgs<ExtArgs>;
};
export type TipIncludeCreateManyAndReturn<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    createdBy?: boolean | Prisma.Tip$createdByArgs<ExtArgs>;
};
export type TipIncludeUpdateManyAndReturn<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    createdBy?: boolean | Prisma.Tip$createdByArgs<ExtArgs>;
};
export type $TipPayload<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    name: "Tip";
    objects: {
        createdBy: Prisma.$StaffUserPayload<ExtArgs> | null;
    };
    scalars: runtime.Types.Extensions.GetPayloadResult<{
        id: number;
        title: string;
        body: string;
        category: string | null;
        audience: string | null;
        ctaLabel: string | null;
        ctaUrl: string | null;
        priority: number;
        isActive: boolean;
        publishAt: Date | null;
        expiresAt: Date | null;
        createdAt: Date;
        updatedAt: Date;
        createdById: number | null;
    }, ExtArgs["result"]["tip"]>;
    composites: {};
};
export type TipGetPayload<S extends boolean | null | undefined | TipDefaultArgs> = runtime.Types.Result.GetResult<Prisma.$TipPayload, S>;
export type TipCountArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = Omit<TipFindManyArgs, 'select' | 'include' | 'distinct' | 'omit'> & {
    select?: TipCountAggregateInputType | true;
};
export interface TipDelegate<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs, GlobalOmitOptions = {}> {
    [K: symbol]: {
        types: Prisma.TypeMap<ExtArgs>['model']['Tip'];
        meta: {
            name: 'Tip';
        };
    };
    /**
     * Find zero or one Tip that matches the filter.
     * @param {TipFindUniqueArgs} args - Arguments to find a Tip
     * @example
     * // Get one Tip
     * const tip = await prisma.tip.findUnique({
     *   where: {
     *     // ... provide filter here
     *   }
     * })
     */
    findUnique<T extends TipFindUniqueArgs>(args: Prisma.SelectSubset<T, TipFindUniqueArgs<ExtArgs>>): Prisma.Prisma__TipClient<runtime.Types.Result.GetResult<Prisma.$TipPayload<ExtArgs>, T, "findUnique", GlobalOmitOptions> | null, null, ExtArgs, GlobalOmitOptions>;
    /**
     * Find one Tip that matches the filter or throw an error with `error.code='P2025'`
     * if no matches were found.
     * @param {TipFindUniqueOrThrowArgs} args - Arguments to find a Tip
     * @example
     * // Get one Tip
     * const tip = await prisma.tip.findUniqueOrThrow({
     *   where: {
     *     // ... provide filter here
     *   }
     * })
     */
    findUniqueOrThrow<T extends TipFindUniqueOrThrowArgs>(args: Prisma.SelectSubset<T, TipFindUniqueOrThrowArgs<ExtArgs>>): Prisma.Prisma__TipClient<runtime.Types.Result.GetResult<Prisma.$TipPayload<ExtArgs>, T, "findUniqueOrThrow", GlobalOmitOptions>, never, ExtArgs, GlobalOmitOptions>;
    /**
     * Find the first Tip that matches the filter.
     * Note, that providing `undefined` is treated as the value not being there.
     * Read more here: https://pris.ly/d/null-undefined
     * @param {TipFindFirstArgs} args - Arguments to find a Tip
     * @example
     * // Get one Tip
     * const tip = await prisma.tip.findFirst({
     *   where: {
     *     // ... provide filter here
     *   }
     * })
     */
    findFirst<T extends TipFindFirstArgs>(args?: Prisma.SelectSubset<T, TipFindFirstArgs<ExtArgs>>): Prisma.Prisma__TipClient<runtime.Types.Result.GetResult<Prisma.$TipPayload<ExtArgs>, T, "findFirst", GlobalOmitOptions> | null, null, ExtArgs, GlobalOmitOptions>;
    /**
     * Find the first Tip that matches the filter or
     * throw `PrismaKnownClientError` with `P2025` code if no matches were found.
     * Note, that providing `undefined` is treated as the value not being there.
     * Read more here: https://pris.ly/d/null-undefined
     * @param {TipFindFirstOrThrowArgs} args - Arguments to find a Tip
     * @example
     * // Get one Tip
     * const tip = await prisma.tip.findFirstOrThrow({
     *   where: {
     *     // ... provide filter here
     *   }
     * })
     */
    findFirstOrThrow<T extends TipFindFirstOrThrowArgs>(args?: Prisma.SelectSubset<T, TipFindFirstOrThrowArgs<ExtArgs>>): Prisma.Prisma__TipClient<runtime.Types.Result.GetResult<Prisma.$TipPayload<ExtArgs>, T, "findFirstOrThrow", GlobalOmitOptions>, never, ExtArgs, GlobalOmitOptions>;
    /**
     * Find zero or more Tips that matches the filter.
     * Note, that providing `undefined` is treated as the value not being there.
     * Read more here: https://pris.ly/d/null-undefined
     * @param {TipFindManyArgs} args - Arguments to filter and select certain fields only.
     * @example
     * // Get all Tips
     * const tips = await prisma.tip.findMany()
     *
     * // Get first 10 Tips
     * const tips = await prisma.tip.findMany({ take: 10 })
     *
     * // Only select the `id`
     * const tipWithIdOnly = await prisma.tip.findMany({ select: { id: true } })
     *
     */
    findMany<T extends TipFindManyArgs>(args?: Prisma.SelectSubset<T, TipFindManyArgs<ExtArgs>>): Prisma.PrismaPromise<runtime.Types.Result.GetResult<Prisma.$TipPayload<ExtArgs>, T, "findMany", GlobalOmitOptions>>;
    /**
     * Create a Tip.
     * @param {TipCreateArgs} args - Arguments to create a Tip.
     * @example
     * // Create one Tip
     * const Tip = await prisma.tip.create({
     *   data: {
     *     // ... data to create a Tip
     *   }
     * })
     *
     */
    create<T extends TipCreateArgs>(args: Prisma.SelectSubset<T, TipCreateArgs<ExtArgs>>): Prisma.Prisma__TipClient<runtime.Types.Result.GetResult<Prisma.$TipPayload<ExtArgs>, T, "create", GlobalOmitOptions>, never, ExtArgs, GlobalOmitOptions>;
    /**
     * Create many Tips.
     * @param {TipCreateManyArgs} args - Arguments to create many Tips.
     * @example
     * // Create many Tips
     * const tip = await prisma.tip.createMany({
     *   data: [
     *     // ... provide data here
     *   ]
     * })
     *
     */
    createMany<T extends TipCreateManyArgs>(args?: Prisma.SelectSubset<T, TipCreateManyArgs<ExtArgs>>): Prisma.PrismaPromise<Prisma.BatchPayload>;
    /**
     * Create many Tips and returns the data saved in the database.
     * @param {TipCreateManyAndReturnArgs} args - Arguments to create many Tips.
     * @example
     * // Create many Tips
     * const tip = await prisma.tip.createManyAndReturn({
     *   data: [
     *     // ... provide data here
     *   ]
     * })
     *
     * // Create many Tips and only return the `id`
     * const tipWithIdOnly = await prisma.tip.createManyAndReturn({
     *   select: { id: true },
     *   data: [
     *     // ... provide data here
     *   ]
     * })
     * Note, that providing `undefined` is treated as the value not being there.
     * Read more here: https://pris.ly/d/null-undefined
     *
     */
    createManyAndReturn<T extends TipCreateManyAndReturnArgs>(args?: Prisma.SelectSubset<T, TipCreateManyAndReturnArgs<ExtArgs>>): Prisma.PrismaPromise<runtime.Types.Result.GetResult<Prisma.$TipPayload<ExtArgs>, T, "createManyAndReturn", GlobalOmitOptions>>;
    /**
     * Delete a Tip.
     * @param {TipDeleteArgs} args - Arguments to delete one Tip.
     * @example
     * // Delete one Tip
     * const Tip = await prisma.tip.delete({
     *   where: {
     *     // ... filter to delete one Tip
     *   }
     * })
     *
     */
    delete<T extends TipDeleteArgs>(args: Prisma.SelectSubset<T, TipDeleteArgs<ExtArgs>>): Prisma.Prisma__TipClient<runtime.Types.Result.GetResult<Prisma.$TipPayload<ExtArgs>, T, "delete", GlobalOmitOptions>, never, ExtArgs, GlobalOmitOptions>;
    /**
     * Update one Tip.
     * @param {TipUpdateArgs} args - Arguments to update one Tip.
     * @example
     * // Update one Tip
     * const tip = await prisma.tip.update({
     *   where: {
     *     // ... provide filter here
     *   },
     *   data: {
     *     // ... provide data here
     *   }
     * })
     *
     */
    update<T extends TipUpdateArgs>(args: Prisma.SelectSubset<T, TipUpdateArgs<ExtArgs>>): Prisma.Prisma__TipClient<runtime.Types.Result.GetResult<Prisma.$TipPayload<ExtArgs>, T, "update", GlobalOmitOptions>, never, ExtArgs, GlobalOmitOptions>;
    /**
     * Delete zero or more Tips.
     * @param {TipDeleteManyArgs} args - Arguments to filter Tips to delete.
     * @example
     * // Delete a few Tips
     * const { count } = await prisma.tip.deleteMany({
     *   where: {
     *     // ... provide filter here
     *   }
     * })
     *
     */
    deleteMany<T extends TipDeleteManyArgs>(args?: Prisma.SelectSubset<T, TipDeleteManyArgs<ExtArgs>>): Prisma.PrismaPromise<Prisma.BatchPayload>;
    /**
     * Update zero or more Tips.
     * Note, that providing `undefined` is treated as the value not being there.
     * Read more here: https://pris.ly/d/null-undefined
     * @param {TipUpdateManyArgs} args - Arguments to update one or more rows.
     * @example
     * // Update many Tips
     * const tip = await prisma.tip.updateMany({
     *   where: {
     *     // ... provide filter here
     *   },
     *   data: {
     *     // ... provide data here
     *   }
     * })
     *
     */
    updateMany<T extends TipUpdateManyArgs>(args: Prisma.SelectSubset<T, TipUpdateManyArgs<ExtArgs>>): Prisma.PrismaPromise<Prisma.BatchPayload>;
    /**
     * Update zero or more Tips and returns the data updated in the database.
     * @param {TipUpdateManyAndReturnArgs} args - Arguments to update many Tips.
     * @example
     * // Update many Tips
     * const tip = await prisma.tip.updateManyAndReturn({
     *   where: {
     *     // ... provide filter here
     *   },
     *   data: [
     *     // ... provide data here
     *   ]
     * })
     *
     * // Update zero or more Tips and only return the `id`
     * const tipWithIdOnly = await prisma.tip.updateManyAndReturn({
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
    updateManyAndReturn<T extends TipUpdateManyAndReturnArgs>(args: Prisma.SelectSubset<T, TipUpdateManyAndReturnArgs<ExtArgs>>): Prisma.PrismaPromise<runtime.Types.Result.GetResult<Prisma.$TipPayload<ExtArgs>, T, "updateManyAndReturn", GlobalOmitOptions>>;
    /**
     * Create or update one Tip.
     * @param {TipUpsertArgs} args - Arguments to update or create a Tip.
     * @example
     * // Update or create a Tip
     * const tip = await prisma.tip.upsert({
     *   create: {
     *     // ... data to create a Tip
     *   },
     *   update: {
     *     // ... in case it already exists, update
     *   },
     *   where: {
     *     // ... the filter for the Tip we want to update
     *   }
     * })
     */
    upsert<T extends TipUpsertArgs>(args: Prisma.SelectSubset<T, TipUpsertArgs<ExtArgs>>): Prisma.Prisma__TipClient<runtime.Types.Result.GetResult<Prisma.$TipPayload<ExtArgs>, T, "upsert", GlobalOmitOptions>, never, ExtArgs, GlobalOmitOptions>;
    /**
     * Count the number of Tips.
     * Note, that providing `undefined` is treated as the value not being there.
     * Read more here: https://pris.ly/d/null-undefined
     * @param {TipCountArgs} args - Arguments to filter Tips to count.
     * @example
     * // Count the number of Tips
     * const count = await prisma.tip.count({
     *   where: {
     *     // ... the filter for the Tips we want to count
     *   }
     * })
    **/
    count<T extends TipCountArgs>(args?: Prisma.Subset<T, TipCountArgs>): Prisma.PrismaPromise<T extends runtime.Types.Utils.Record<'select', any> ? T['select'] extends true ? number : Prisma.GetScalarType<T['select'], TipCountAggregateOutputType> : number>;
    /**
     * Allows you to perform aggregations operations on a Tip.
     * Note, that providing `undefined` is treated as the value not being there.
     * Read more here: https://pris.ly/d/null-undefined
     * @param {TipAggregateArgs} args - Select which aggregations you would like to apply and on what fields.
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
    aggregate<T extends TipAggregateArgs>(args: Prisma.Subset<T, TipAggregateArgs>): Prisma.PrismaPromise<GetTipAggregateType<T>>;
    /**
     * Group by Tip.
     * Note, that providing `undefined` is treated as the value not being there.
     * Read more here: https://pris.ly/d/null-undefined
     * @param {TipGroupByArgs} args - Group by arguments.
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
    groupBy<T extends TipGroupByArgs, HasSelectOrTake extends Prisma.Or<Prisma.Extends<'skip', Prisma.Keys<T>>, Prisma.Extends<'take', Prisma.Keys<T>>>, OrderByArg extends Prisma.True extends HasSelectOrTake ? {
        orderBy: TipGroupByArgs['orderBy'];
    } : {
        orderBy?: TipGroupByArgs['orderBy'];
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
    }[OrderFields]>(args: Prisma.SubsetIntersection<T, TipGroupByArgs, OrderByArg> & InputErrors): {} extends InputErrors ? GetTipGroupByPayload<T> : Prisma.PrismaPromise<InputErrors>;
    /**
     * Fields of the Tip model
     */
    readonly fields: TipFieldRefs;
}
/**
 * The delegate class that acts as a "Promise-like" for Tip.
 * Why is this prefixed with `Prisma__`?
 * Because we want to prevent naming conflicts as mentioned in
 * https://github.com/prisma/prisma-client-js/issues/707
 */
export interface Prisma__TipClient<T, Null = never, ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs, GlobalOmitOptions = {}> extends Prisma.PrismaPromise<T> {
    readonly [Symbol.toStringTag]: "PrismaPromise";
    createdBy<T extends Prisma.Tip$createdByArgs<ExtArgs> = {}>(args?: Prisma.Subset<T, Prisma.Tip$createdByArgs<ExtArgs>>): Prisma.Prisma__StaffUserClient<runtime.Types.Result.GetResult<Prisma.$StaffUserPayload<ExtArgs>, T, "findUniqueOrThrow", GlobalOmitOptions> | null, null, ExtArgs, GlobalOmitOptions>;
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
 * Fields of the Tip model
 */
export interface TipFieldRefs {
    readonly id: Prisma.FieldRef<"Tip", 'Int'>;
    readonly title: Prisma.FieldRef<"Tip", 'String'>;
    readonly body: Prisma.FieldRef<"Tip", 'String'>;
    readonly category: Prisma.FieldRef<"Tip", 'String'>;
    readonly audience: Prisma.FieldRef<"Tip", 'String'>;
    readonly ctaLabel: Prisma.FieldRef<"Tip", 'String'>;
    readonly ctaUrl: Prisma.FieldRef<"Tip", 'String'>;
    readonly priority: Prisma.FieldRef<"Tip", 'Int'>;
    readonly isActive: Prisma.FieldRef<"Tip", 'Boolean'>;
    readonly publishAt: Prisma.FieldRef<"Tip", 'DateTime'>;
    readonly expiresAt: Prisma.FieldRef<"Tip", 'DateTime'>;
    readonly createdAt: Prisma.FieldRef<"Tip", 'DateTime'>;
    readonly updatedAt: Prisma.FieldRef<"Tip", 'DateTime'>;
    readonly createdById: Prisma.FieldRef<"Tip", 'Int'>;
}
/**
 * Tip findUnique
 */
export type TipFindUniqueArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
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
    /**
     * Filter, which Tip to fetch.
     */
    where: Prisma.TipWhereUniqueInput;
};
/**
 * Tip findUniqueOrThrow
 */
export type TipFindUniqueOrThrowArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
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
    /**
     * Filter, which Tip to fetch.
     */
    where: Prisma.TipWhereUniqueInput;
};
/**
 * Tip findFirst
 */
export type TipFindFirstArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
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
    /**
     * Filter, which Tip to fetch.
     */
    where?: Prisma.TipWhereInput;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/sorting Sorting Docs}
     *
     * Determine the order of Tips to fetch.
     */
    orderBy?: Prisma.TipOrderByWithRelationInput | Prisma.TipOrderByWithRelationInput[];
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/pagination#cursor-based-pagination Cursor Docs}
     *
     * Sets the position for searching for Tips.
     */
    cursor?: Prisma.TipWhereUniqueInput;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/pagination Pagination Docs}
     *
     * Take `±n` Tips from the position of the cursor.
     */
    take?: number;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/pagination Pagination Docs}
     *
     * Skip the first `n` Tips.
     */
    skip?: number;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/distinct Distinct Docs}
     *
     * Filter by unique combinations of Tips.
     */
    distinct?: Prisma.TipScalarFieldEnum | Prisma.TipScalarFieldEnum[];
};
/**
 * Tip findFirstOrThrow
 */
export type TipFindFirstOrThrowArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
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
    /**
     * Filter, which Tip to fetch.
     */
    where?: Prisma.TipWhereInput;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/sorting Sorting Docs}
     *
     * Determine the order of Tips to fetch.
     */
    orderBy?: Prisma.TipOrderByWithRelationInput | Prisma.TipOrderByWithRelationInput[];
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/pagination#cursor-based-pagination Cursor Docs}
     *
     * Sets the position for searching for Tips.
     */
    cursor?: Prisma.TipWhereUniqueInput;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/pagination Pagination Docs}
     *
     * Take `±n` Tips from the position of the cursor.
     */
    take?: number;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/pagination Pagination Docs}
     *
     * Skip the first `n` Tips.
     */
    skip?: number;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/distinct Distinct Docs}
     *
     * Filter by unique combinations of Tips.
     */
    distinct?: Prisma.TipScalarFieldEnum | Prisma.TipScalarFieldEnum[];
};
/**
 * Tip findMany
 */
export type TipFindManyArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
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
    /**
     * Filter, which Tips to fetch.
     */
    where?: Prisma.TipWhereInput;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/sorting Sorting Docs}
     *
     * Determine the order of Tips to fetch.
     */
    orderBy?: Prisma.TipOrderByWithRelationInput | Prisma.TipOrderByWithRelationInput[];
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/pagination#cursor-based-pagination Cursor Docs}
     *
     * Sets the position for listing Tips.
     */
    cursor?: Prisma.TipWhereUniqueInput;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/pagination Pagination Docs}
     *
     * Take `±n` Tips from the position of the cursor.
     */
    take?: number;
    /**
     * {@link https://www.prisma.io/docs/concepts/components/prisma-client/pagination Pagination Docs}
     *
     * Skip the first `n` Tips.
     */
    skip?: number;
    distinct?: Prisma.TipScalarFieldEnum | Prisma.TipScalarFieldEnum[];
};
/**
 * Tip create
 */
export type TipCreateArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
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
    /**
     * The data needed to create a Tip.
     */
    data: Prisma.XOR<Prisma.TipCreateInput, Prisma.TipUncheckedCreateInput>;
};
/**
 * Tip createMany
 */
export type TipCreateManyArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    /**
     * The data used to create many Tips.
     */
    data: Prisma.TipCreateManyInput | Prisma.TipCreateManyInput[];
};
/**
 * Tip createManyAndReturn
 */
export type TipCreateManyAndReturnArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    /**
     * Select specific fields to fetch from the Tip
     */
    select?: Prisma.TipSelectCreateManyAndReturn<ExtArgs> | null;
    /**
     * Omit specific fields from the Tip
     */
    omit?: Prisma.TipOmit<ExtArgs> | null;
    /**
     * The data used to create many Tips.
     */
    data: Prisma.TipCreateManyInput | Prisma.TipCreateManyInput[];
    /**
     * Choose, which related nodes to fetch as well
     */
    include?: Prisma.TipIncludeCreateManyAndReturn<ExtArgs> | null;
};
/**
 * Tip update
 */
export type TipUpdateArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
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
    /**
     * The data needed to update a Tip.
     */
    data: Prisma.XOR<Prisma.TipUpdateInput, Prisma.TipUncheckedUpdateInput>;
    /**
     * Choose, which Tip to update.
     */
    where: Prisma.TipWhereUniqueInput;
};
/**
 * Tip updateMany
 */
export type TipUpdateManyArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    /**
     * The data used to update Tips.
     */
    data: Prisma.XOR<Prisma.TipUpdateManyMutationInput, Prisma.TipUncheckedUpdateManyInput>;
    /**
     * Filter which Tips to update
     */
    where?: Prisma.TipWhereInput;
    /**
     * Limit how many Tips to update.
     */
    limit?: number;
};
/**
 * Tip updateManyAndReturn
 */
export type TipUpdateManyAndReturnArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    /**
     * Select specific fields to fetch from the Tip
     */
    select?: Prisma.TipSelectUpdateManyAndReturn<ExtArgs> | null;
    /**
     * Omit specific fields from the Tip
     */
    omit?: Prisma.TipOmit<ExtArgs> | null;
    /**
     * The data used to update Tips.
     */
    data: Prisma.XOR<Prisma.TipUpdateManyMutationInput, Prisma.TipUncheckedUpdateManyInput>;
    /**
     * Filter which Tips to update
     */
    where?: Prisma.TipWhereInput;
    /**
     * Limit how many Tips to update.
     */
    limit?: number;
    /**
     * Choose, which related nodes to fetch as well
     */
    include?: Prisma.TipIncludeUpdateManyAndReturn<ExtArgs> | null;
};
/**
 * Tip upsert
 */
export type TipUpsertArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
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
    /**
     * The filter to search for the Tip to update in case it exists.
     */
    where: Prisma.TipWhereUniqueInput;
    /**
     * In case the Tip found by the `where` argument doesn't exist, create a new Tip with this data.
     */
    create: Prisma.XOR<Prisma.TipCreateInput, Prisma.TipUncheckedCreateInput>;
    /**
     * In case the Tip was found with the provided `where` argument, update it with this data.
     */
    update: Prisma.XOR<Prisma.TipUpdateInput, Prisma.TipUncheckedUpdateInput>;
};
/**
 * Tip delete
 */
export type TipDeleteArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
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
    /**
     * Filter which Tip to delete.
     */
    where: Prisma.TipWhereUniqueInput;
};
/**
 * Tip deleteMany
 */
export type TipDeleteManyArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
    /**
     * Filter which Tips to delete
     */
    where?: Prisma.TipWhereInput;
    /**
     * Limit how many Tips to delete.
     */
    limit?: number;
};
/**
 * Tip.createdBy
 */
export type Tip$createdByArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
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
 * Tip without action
 */
export type TipDefaultArgs<ExtArgs extends runtime.Types.Extensions.InternalArgs = runtime.Types.Extensions.DefaultArgs> = {
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
};
export {};
//# sourceMappingURL=Tip.d.ts.map